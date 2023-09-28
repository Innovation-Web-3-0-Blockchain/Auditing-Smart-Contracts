VulnerableLenderPool.sol

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface IFlashLoanEtherReceiver {
    function execute(uint256 fee) external payable;
}

contract VulnerableLenderPool {
    uint256 public feePercent = 1;
    uint256 positionAmount = 1 ether / 4;
    uint256 public positionCount;
    address public owner;
    // address -> array that contains where users positions are located in the positionToDepositor mapping
    mapping(address => uint256[]) public positionLocations;
    // position -> depositor
    mapping(uint256 => address) public positionToDepositor;

    constructor() {
        owner = msg.sender;
    }

    function setFeePercent(uint256 _percent) external {
        require(tx.origin == owner, "Only owner");
        feePercent = _percent;
    }

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

    function withdraw(uint256 _amountOfPositions) external {
        // transfer ether
        console.log(address(this).balance);
        console.log(positionAmount);
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

    function getBalance(address _depositor) external view returns (uint256) {
        return (positionLocations[_depositor].length * positionAmount);
    }

    function getFee(uint256 _borrowAmount) public view returns (uint256) {
        return (_borrowAmount * (feePercent / 100));
    }

    function flashLoan(address borrowingContract, uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        // Get fee the correct way. getFee function is incorrect
        uint256 _fee = (amount * feePercent) / 100;
        // Lend funds to recieving contract
        IFlashLoanEtherReceiver(borrowingContract).execute{value: amount}(_fee);
        require(
            address(this).balance >= balanceBefore + _fee,
            "Flash loan hasn't been paid back"
        );
        bytes32 result = keccak256(
            abi.encodePacked(
                uint256(block.difficulty),
                uint256(block.timestamp)
            )
        );

        uint256 randomNumber = uint256(result) % positionCount;
        // Pay fee to one of the depositors.
        // We get the lucky depositer using the positionToDeposit mapping, looking up the depositor at a random position.
        payable(positionToDepositor[randomNumber + 1]).transfer(_fee);
    }

    // Required to receieve fees
    receive() external payable {}
}