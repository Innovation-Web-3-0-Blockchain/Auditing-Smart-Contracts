// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Import the Chainlink VRFConsumerBase contract.
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// Import the OpenZeppelin ReentrancyGuard contract for preventing reentrancy attacks.
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Import the Hardhat console library for debugging
import "hardhat/console.sol";

// Interface for a contract that can receive flash loans
interface IFlashLoanEtherReceiver {
    function execute(uint256 fee) external payable;
}

// Main contract, inherits from VRFConsumerBase and ReentrancyGuard
contract SecureLenderPool is VRFConsumerBase, ReentrancyGuard {
    uint256 public feePercent = 1; // The fee percentage for flash loans
    uint256 positionAmount = 1 ether / 4; // The amount for each position
    uint256 public positionCount; // Total number of positions
    bytes32 internal keyHash; // Chainlink VRF key hash
    uint256 internal fee; // Chainlink VRF fee
    uint256 public randomResult; // The result of the random number generation
    address public owner; // Owner of the contract

    // Mapping to track the positions of each user
    mapping(address => uint256[]) public positionLocations;
    // Mapping to associate positions with depositors
    mapping(uint256 => address) public positionToDepositor;

    // Constructor to initialize the contract with Chainlink VRF settings
    constructor()
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088 // LINK Token
        )
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10**18; // 0.1 LINK
        owner = msg.sender; // Set the contract owner
    }

    // Function to set the fee percentage (only callable by the owner)
    function setFeePercent(uint256 _percent) external {
        require(msg.sender == owner, "Only owner");
        feePercent = _percent;
    }

    // Function to deposit funds into the contract
    function deposit() external payable nonReentrant {
        require(msg.value <= 100 ether, "Can't deposit more than 100 ether at a time");
        require(msg.value > 0, "Deposit must be greater than zero");
        require(msg.value % positionAmount == 0, "Deposit value must be an interval of the interval amount");

        uint256 _positionCount = positionCount;
        uint256 _deposits;

        // Loop to handle multiple deposits
        while (_deposits < msg.value / positionAmount) {
            _deposits++;
            positionLocations[msg.sender].push(_positionCount + _deposits);
            positionToDepositor[_positionCount + _deposits] = msg.sender;
        }

        positionCount += _deposits;
    }

    // Function to withdraw funds from the contract
    function withdraw(uint256 _amountOfPositions) external nonReentrant {
        require(_amountOfPositions <= positionLocations[msg.sender].length, "Insufficient deposit balance");
        uint256 _positionCount = positionCount;

        uint256[] memory _positions = new uint256[](positionLocations[msg.sender].length);
        _positions = positionLocations[msg.sender];

        // Loop to shift positions when withdrawing
        for (uint256 i = 0; i < _amountOfPositions; i++) {
            address shiftedAddr = positionToDepositor[_positionCount - i];
            uint256 shift = _positions[_positions.length - (1 + i)];
            positionToDepositor[shift] = shiftedAddr;
            for (uint256 j = 0; j < positionLocations[shiftedAddr].length; j++) {
                if (positionLocations[shiftedAddr][j] == _positionCount - i) {
                    positionLocations[shiftedAddr][j] = shift;
                    break;
                }
            }
        }

        uint256[] memory _remainingPositions = new uint256[](_positions.length - _amountOfPositions);

        // Copy the remaining positions
        for (uint256 i = 0; i < _remainingPositions.length; i++) {
            _remainingPositions[i] = _positions[i];
        }

        positionLocations[msg.sender] = _remainingPositions;
        positionCount -= _amountOfPositions;

        // Transfer Ether to the user
        (bool sent, ) = payable(msg.sender).call{ value: _amountOfPositions * positionAmount }("");
        require(sent, "Failed to send Ether");
    }

    // Function to get the balance of a depositor
    function getBalance(address _depositor) external view returns (uint256) {
        return (positionLocations[_depositor].length * positionAmount);
    }

    // Function to calculate the fee for a flash loan
    function getFee(uint256 _borrowAmount) public view returns (uint256) {
        return (_borrowAmount * feePercent) / 100;
    }

    // Function to initiate a flash loan
    function flashLoan(address borrowingContract, uint256 amount) external nonReentrant {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");

        // Get a random number from Chainlink VRF
        requestRandomness(keyHash, fee);

        // Calculate the fee for the flash loan
        uint256 _fee = getFee(amount);

        // Lend funds to the receiving contract
        IFlashLoanEtherReceiver(borrowingContract).execute{ value: amount }(_fee);

        // Check if the contract balance increased by the fee amount
        require(address(this).balance >= balanceBefore + _fee, "Flash loan hasn't been paid back");

        // Pay the fee to one of the depositors randomly
        // We get the lucky depositor using the positionToDeposit mapping, looking up the depositor at a random position.
        payable(positionToDepositor[(randomResult % positionCount) + 1]).transfer(_fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        randomResult = randomness;
    }

    // Fallback function to receive Ether (required to receive fees)
    receive() external payable {}
}
