// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Hypothetical Scenario:
// Imagine a situation where a hacker discovers that a user of a lending pool
// has deployed a flash loan receiving contract on Etherscan. After analyzing
// the contract's code, the hacker identifies a vulnerability and attempts to
// exploit it to gain control over and steal all the Ether stored within the contract.

// Define the FlashLoanReceiver contract
contract FlashLoanReceiver {
    // Array to store addresses of two lending pools
    address payable[2] public pools;

    // Address of the contract owner
    address public owner;

    // Constructor to initialize the FlashLoanReceiver contract
    constructor(address payable[2] memory poolAddresses) {
        pools = poolAddresses;
        owner = msg.sender;
    }

    // Function called by the pool during a flash loan
    function execute(uint256 fee) public payable {
        // Ensure that the caller of the function is the owner
        require(tx.origin == owner);

        // Ensure that the caller is one of the two lending pools
        require(
            msg.sender == pools[1] || msg.sender == pools[0],
            "Sender must be a pool"
        );

        // Calculate the total amount to be repaid, including the fee
        uint256 amountToBeRepaid = msg.value + fee;

        // Ensure that the contract has enough balance to repay the loan
        require(
            address(this).balance >= amountToBeRepaid,
            "Cannot borrow that much"
        );

        // Execute the action during the flash loan
        _executeActionDuringFlashLoan();

        // Return funds to the lending pool
        (bool sent, ) = msg.sender.call{value: amountToBeRepaid}("");
        require(sent, "Failed to send Ether");
    }

    // Internal function where the funds received are used
    function _executeActionDuringFlashLoan() internal {}

    // Allow deposits of ETH
    receive() external payable {}
}
