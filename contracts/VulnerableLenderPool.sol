// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import for debugging console
import "hardhat/console.sol";

// Interface for a contract that can receive flash loans
interface IFlashLoanEtherReceiver {
    function execute(uint256 fee) external payable;
}

// Main contract - VulnerableLenderPool
contract VulnerableLenderPool {
    // Public state variables
    uint256 public feePercent = 1; // The fee percentage for flash loans
    uint256 positionAmount = 1 ether / 4; // The amount for each position
    uint256 public positionCount; // Total number of positions
    address public owner; // Owner of the contract

    // Mapping to track the positions of each user
    mapping(address => uint256[]) public positionLocations;
    // Mapping to associate positions with depositors
    mapping(uint256 => address) public positionToDepositor;

    // Constructor
    constructor() {
        owner = msg.sender; // Set the contract owner to the deployer
    }

    // Function to set the fee percentage (only callable by the owner)
    function setFeePercent(uint256 _percent) external {
        require(tx.origin == owner, "Only owner");
        feePercent = _percent;
    }

    // Function to deposit funds into the contract
    function deposit() external payable {
        require(msg.value > 0, "Deposit must be greater than zero");
        uint256 _positionCount = positionCount;
        uint256 _deposits;
        while (_deposits < msg.value / positionAmount) {
            _deposits++;
            positionLocations[msg.sender].push(_positionCount + _deposits);
            positionToDepositor[_positionCount + _deposits] = msg.sender;
        }
        positionCount += _deposits;
    }

    // Function to withdraw funds from the contract
    function withdraw(uint256 _amountOfPositions) external {
        // Transfer Ether to the caller
        (bool sent, ) = payable(msg.sender).call{
            value: _amountOfPositions * positionAmount
        }("");
        require(sent, "Failed to send Ether");

        uint256 _positionCount = positionCount;

        uint256[] memory _positions = new uint256[](
            positionLocations[msg.sender].length
        );

        _positions = positionLocations[msg.sender];

        for (uint256 i = 0; i < _amountOfPositions; i++) {
            address shiftedAddr = positionToDepositor[_positionCount - i];
            uint256 shift = _positions[_positions.length - (1 + i)];
            positionToDepositor[shift] = shiftedAddr;
            for (
                uint256 j = 0;
                j < positionLocations[shiftedAddr].length;
                j++
            ) {
                if (positionLocations[shiftedAddr][j] == _positionCount - i) {
                    positionLocations[shiftedAddr][j] = shift;
                    break;
                }
            }
        }

        uint256[] memory _remainingPositions = new uint256[](
            _positions.length - _amountOfPositions
        );

        for (uint256 i = 0; i < _remainingPositions.length; i++) {
            _remainingPositions[i] = _positions[i];
        }

        positionLocations[msg.sender] = _remainingPositions;
        positionCount -= _amountOfPositions;
    }

    // Function to get the balance of a depositor
    function getBalance(address _depositor) external view returns (uint256) {
        return (positionLocations[_depositor].length * positionAmount);
    }

    // Function to calculate the fee for a flash loan
    function getFee(uint256 _borrowAmount) public view returns (uint256) {
        return (_borrowAmount * (feePercent / 100));
    }

    // Function to initiate a flash loan
    function flashLoan(address borrowingContract, uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");

        // Calculate the fee for the flash loan
        uint256 _fee = (amount * feePercent) / 100;

        // Execute the flash loan
        IFlashLoanEtherReceiver(borrowingContract).execute{value: amount}(_fee);

        require(
            address(this).balance >= balanceBefore + _fee,
            "Flash loan hasn't been paid back"
        );

        // Generate a random number
        bytes32 result = keccak256(
            abi.encodePacked(
                uint256(block.difficulty),
                uint256(block.timestamp)
            )
        );
        uint256 randomNumber = uint256(result) % positionCount;

        // Pay the fee to one of the depositors at random
        payable(positionToDepositor[randomNumber + 1]).transfer(_fee);
    }

    // Required to receive fees
    receive() external payable {}
}