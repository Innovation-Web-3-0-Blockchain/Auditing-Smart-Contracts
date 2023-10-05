// This test script primarily focuses on identifying vulnerabilities in the VulnerableLenderPool.sol contract
// and verifying the effectiveness of the patches applied in the SecureLenderPool.sol contract.

// Import necessary modules
const { expect } = require("chai");
const { ethers } = require("hardhat");

// Describe the test suite
describe("Common solidity pitfalls", function () {
  let vulnerablePool, securePool, receiver, attack;
  let deployer, artist, miner, user1, user2, attacker, users;

  // Set up contracts and signers before each test case
  beforeEach(async function () {
    // Get the ContractFactory for different contracts
    const VulnerablePoolFactory = await ethers.getContractFactory("VulnerableLenderPool");
    const SecurePoolFactory = await ethers.getContractFactory("SecureLenderPool");
    const FlashLoanReceiverFactory = await ethers.getContractFactory('FlashLoanReceiver');
    const AttackFactory = await ethers.getContractFactory("Attack");

    // Get the signers
    [deployer, artist, attacker, miner, user1, user2, ...users] = await ethers.getSigners();

    // Deploy contracts
    vulnerablePool = await VulnerablePoolFactory.deploy();
    securePool = await SecurePoolFactory.deploy();
    receiver = await FlashLoanReceiverFactory.deploy([vulnerablePool.address, securePool.address]);
    attack = await AttackFactory.deploy([vulnerablePool.address, securePool.address]);
  });

  // Test case: Missing input or precondition check
  it("Missing input or precondition check", async function () {
    const depositAmount = ethers.utils.parseEther("4.2");

    // It will not precisely track the balance of users who deposit amounts
    // that aren't divisible by the position amount.

    // User makes a deposit to the Vulnerable pool with a non-divisible amount.
    await vulnerablePool.deposit({ value: depositAmount });

    // Retrieve the balance of the deployer's address from the Vulnerable pool.
    let result = await vulnerablePool.getBalance(deployer.address);

    // Expectation: The retrieved balance should not equal the deposited amount,
    // as the Vulnerable pool does not handle non-divisible deposits accurately.
    expect(result).to.not.equal(depositAmount);

    // Expectation: The retrieved balance should equal the nearest lower divisible amount,
    // which is 4 ethers in this case.
    expect(result).to.equal(ethers.utils.parseEther("4"));

    // Secure pool checks that deposit amounts are divisible by position amount,
    // so pool will always track balances precisely.
    // This section of code tests the Secure Pool contract.

    // Attempt to make a deposit with an amount that is not divisible by the position amount,
    // which should trigger a revert with an error message.
    await expect(securePool.deposit({ value: depositAmount })).to.be.revertedWith("Error, deposit value must be an interval of the interval amount");

    // Now, make a valid deposit with an amount that is divisible by the position amount.
    let newDepositAmount = ethers.utils.parseEther("4");
    await securePool.deposit({ value: newDepositAmount });

    // Check if the balance of the deployer's address in the Secure Pool contract
    // matches the newly deposited amount, ensuring precise tracking of balances.
    expect(await securePool.getBalance(deployer.address)).to.equal(newDepositAmount);
  });

  // Test case: Phishing vulnerability with tx.origin
  it("Phishing vulnerability with tx.origin", async function () {
    // Attacker tricks the owner of the vulnerable pool into calling a phishing malicious contract.
    // This action allows the malicious contract to act on the deployer's behalf
    // and set the fee percent on their lender pool to 100%.
    await attack.phishing(0);
    expect(await vulnerablePool.feePercent()).to.equal(100);

    // Attacker attempts the same phishing attack on the secure pool,
    // but it should fail because the set fee function in the secure pool
    // uses msg.sender to authenticate instead of tx.origin.
    await expect(attack.phishing(1)).to.be.revertedWith("Only owner");
  });

    // Test case: Incorrect calculation of output token amount
  it("Incorrect calculation of output token amount", async function () {
    const tokenAmount = ethers.utils.parseEther("100");

    // Call the vulnerable pool's getFee function with a token amount of 100.
    // It's expected to return 0 because of an incorrect order of operations in the calculation (dividing then multiplying).
    expect(await vulnerablePool.getFee(tokenAmount)).to.equal(0);

    // Call the secure pool's getFee function with a token amount of 100.
    // It's expected to return the correct fee amount of 1 ether
    // because it calculates it with the correct order of operations (multiplying then dividing).
    expect(await securePool.getFee(tokenAmount)).to.equal(ethers.utils.parseEther("1"));
  });

  // Test case: Timestamp manipulation
  // NOTE: This vulnerability work only with PoW
  it("Timestamp manipulation", async function () {
    // user1 deposits 1 ether into their receiver contract
    await user1.sendTransaction({ to: receiver.address, value: ethers.utils.parseEther("1") });

    // Deployer deposits 1.5 ether into the vulnerablePool contract
    await vulnerablePool.deposit({ value: ethers.utils.parseEther("1.5") });

    // Miner deposits the minimum amount of 0.25 ether into the vulnerablePool
    await (await vulnerablePool.connect(miner).deposit({ value: ethers.utils.parseEther(".25") })).wait();

    // Get the current balance of the vulnerablePool contract
    const poolBalance = await ethers.provider.getBalance(vulnerablePool.address);

    // Get the total number of positions in the vulnerablePool
    const positionCount = await vulnerablePool.positionCount();

    // Get the block difficulty for the block that will include the flash loan transaction
    let difficulty = 132608;

    // Get the information about the latest Ethereum block
    let block = await ethers.provider.getBlock("latest");

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //                                                                                              //
  //    Due to the average block production rate of approximately one block every 15 seconds,     //
  //    miners who successfully solve the cryptographic puzzle for a block have the opportunity   //
  //    to choose from 15 different timestamp values. This allows them to generate 15 distinct    //
  //    random numbers. If one of these random numbers happens to select their 7th position       //
  //    to receive the fee, they can intentionally publish the block with the timestamp that      //
  //    generated that specific number. As a result, the miner significantly increases their      //
  //    chances (by a factor of 15) of receiving the fee. This method of fee distribution is      //
  //    inherently unfair to depositors.                                                          //
  //                                                                                              //
  //    In contrast, the secure pool ensures fair fee distribution by utilizing Chainlink's       //
  //    verified randomness, which provides a random number that is independent of the block's    //
  //    timestamp. This eliminates the miner's ability to manipulate fee distribution in their    //
  //    favor.                                                                                    //
  //                                                                                              //
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Loop 15 times to simulate different block timestamps
  for (let i = 1; i <= 15; i++) {
    // Generate a hash using block difficulty and an adjusted timestamp
    const hash = ethers.utils.solidityKeccak256(["uint256", "uint256"], [difficulty, block.timestamp + i])
    const number = ethers.BigNumber.from(hash).mod(positionCount)
    
    if (number.toNumber() + 1 == positionCount.toNumber()) {
      // Increase the Ethereum Virtual Machine (EVM) timestamp by 'i' seconds
      await ethers.provider.send("evm_increaseTime", [i]);

      // Get the initial Ethereum balance of the miner
      const initEthBalance = await miner.getBalance();

      // Execute a flash loan transaction
      const tx = await vulnerablePool.connect(deployer).flashLoan(receiver.address, poolBalance);
      await tx.wait();

      // Get the final Ethereum balance of the miner
      const finalEthBalance = await miner.getBalance();
      
      // Check if the miner's balance increased by the expected fee amount using Chai's expect
      const expectedFee = ethers.BigNumber.from('17500000000000000');
      expect(finalEthBalance.sub(initEthBalance)).to.equal(expectedFee);

      // Exit the loop since the condition is met
      break;
     }
    }
  });
});