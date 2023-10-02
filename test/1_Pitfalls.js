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
});
