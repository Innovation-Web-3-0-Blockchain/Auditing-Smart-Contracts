# Contracts 

- [VulnerableLenderPool Contract](#vulnerablelenderpool-contract)
- [Attack Contract](#attack-contract)
- [SecureLenderPool Contract](#securelenderpool-contract)
- [Pitfalls Test](#pitfalls-test)

---

## VulnerableLenderPool Contract 

The `VulnerableLenderPool.sol` contract presents several critical vulnerabilities that could be exploited by malicious actors to compromise the integrity of the contract and potentially inflict financial harm on users. These vulnerabilities and their associated risks are as follows:

1. **Lack of Access Control:**
   - **Vulnerability:** The contract doesn't have proper access control mechanisms for critical functions like setting the fee percentage (`setFeePercent`). It relies on the `tx.origin` check, which is outdated and insecure.
   - **Potential Exploit:** An attacker can potentially call the `setFeePercent` function by manipulating the `tx.origin`, taking control of the fee percentage, and potentially siphoning off funds. 

2. **Reentrancy Vulnerability:**
   - **Vulnerability:** The `flashLoan` function doesn't follow the Checks-Effects-Interactions pattern, making it susceptible to reentrancy attacks.
   - **Potential Exploit:** An attacker can create a malicious borrowing contract that performs a reentrant call to the `flashLoan` function and execute malicious code while inside the vulnerable contract. This can result in fund theft or contract manipulation.

3. **Randomness Vulnerability:**
   - **Vulnerability:** The contract attempts to generate randomness using `keccak256(block.difficulty, block.timestamp)`. However, this method is predictable and can be manipulated by miners.
   - **Potential Exploit:** A miner with sufficient control over the network can manipulate the random number generation, potentially favoring themselves or others in the distribution of fees.

4. **Array Manipulation Vulnerability:**
   - **Vulnerability:** The contract uses arrays extensively without proper bounds checking, which can lead to out-of-bounds access and manipulation.
   - **Potential Exploit:** An attacker could manipulate array indices and positions, potentially causing funds to be misallocated or users' balances to be tampered with.

5. **Front-Running Vulnerability:**
   - **Vulnerability:** The contract lacks mechanisms to prevent front-running, allowing attackers to exploit price or order manipulation.
   - **Potential Exploit:** An attacker could front-run transactions, such as deposit or withdrawal requests, to their advantage, potentially causing financial losses to other users.

6. **Token Handling Vulnerability:**
   - **Vulnerability:** The contract doesn't implement proper token standards or safety checks when handling tokens, which could lead to unintended behavior.
   - **Potential Exploit:** Malicious actors could exploit vulnerabilities in the token handling code to steal or manipulate users' assets.

7. **Fee Calculation Vulnerability:**
   - **Vulnerability:** The calculation of fees is performed using integer division (`feePercent / 100`) without considering rounding issues.
   - **Potential Exploit:** Depending on the value of `feePercent`, this could result in incorrect fee calculations, leading to loss of funds or failed loan repayments.

8. **Lack of Event Logging:**
   - **Vulnerability:** The contract doesn't emit events for critical actions, making it difficult to track and audit transactions.
   - **Potential Exploit:** Without proper event logging, it becomes challenging to monitor and analyze the contract's behavior, making it easier for malicious activities to go unnoticed.

9. **Gas Limitations:**
   - **Vulnerability:** The contract doesn't check or limit the gas consumption of external calls.
   - **Potential Exploit:** An attacker can deploy malicious contracts that consume excessive gas, causing transactions to fail and potentially disrupting the contract's operation.

---

## Attack Contract

The `Attack.sol` contract is used to exploit vulnerabilities in the `VulnerableLenderPool.sol` contract on behalf of the owner. Here's a breakdown of the functions and components of this contract:

1. **Pool Interface**:
   - This contract defines an interface called `Pool` that other contracts can use to interact with pool contracts. The interface includes several functions that can be called on pool contracts.

2. **Attack Contract**:
   - The main contract in this code is called `Attack`. It is intended to interact with instances of the `VulnerableLenderPool.sol` contract.
   
3. **Constructor**:
   - The constructor of the `Attack.sol` contract takes an array of two `Pool` instances as an argument and initializes the `pools` array with these instances.

4. **Phishing Function**:
   - The `phishing` function is designed to perform a phishing attack on one of the pool contracts. It takes an argument `_type` which determines which pool to target.
   - Inside the function, it sets the fee percentage of the specified pool to 100%.

5. **Fallback Function**:
   - The `receive` function is a fallback function that is triggered when the contract receives ETH.
   - It first declares a local variable `_pool` of type `Pool`.
   - It checks if the sender of the transaction is the address of pool 0. If yes, it assigns the instance of pool 0 to `_pool`. Otherwise, it assigns the instance of pool 1.
   - It then checks if the balance of the selected pool is greater than zero, and if so, it attempts to withdraw 1 unit of positions from the selected pool.
   - It allows the contract to withdraw from the selected pool if there are funds available.

---

## SecureLenderPool Contract

The `SecureLenderPool.sol` contract represents a significant enhancement in the security and functionality of the flash loan lending pool in comparison to its vulnerable predecessor. The following key improvements have been implemented to fortify the contract's security posture:

1. **Access Control Improvement:**
   - The `setFeePercent` function now includes a proper access control check to ensure that only the owner of the contract can modify the fee percentage. This prevents unauthorized changes to the fee structure.

2. **Reentrancy Protection:**
   - The patched contract now inherits from the `ReentrancyGuard` contract provided by OpenZeppelin, which helps protect against reentrancy attacks.

3. **Fee Calculation Improvement:**
   - The `getFee` function has been updated to use proper integer division for fee calculations, addressing potential rounding issues.

4. **Randomness Enhancement:**
   - The contract uses Chainlink's VRF (Verifiable Random Function) to obtain a random number, enhancing the randomness of selecting a depositor to receive the fee.

5. **Withdrawal Logic Enhancement:**
   - The withdrawal logic has been improved to ensure that only the sender's positions are withdrawn, preventing unauthorized withdrawal of other users' positions.

6. **Deposit Limit:**
   - The contract now includes a limit on the maximum deposit amount per transaction to prevent excessive deposits and potential abuse.

7. **Gas Limitation Consideration:**
   - The patched contract incorporates checks to ensure that there is enough LINK tokens (for Chainlink VRF) and Ether in the contract before initiating a flash loan, reducing the risk of failed transactions.

8. **Fallback Function Update:**
   - The fallback function now checks if there are positions to withdraw before attempting to transfer Ether to the user, preventing unnecessary transfers.

---

## Pitfalls Test

To Run a pitfalls test:

```bash
npx hardhat test test/Pitfalls.js
```

---
