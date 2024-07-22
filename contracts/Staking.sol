// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking is AccessControl, ReentrancyGuard {
    bytes32 public constant LIQUIDITY_MANAGER_ROLE = keccak256("LIQUIDITY_MANAGER_ROLE");

    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public unstakeTimestamps;
    uint256 public constant COOLDOWN_PERIOD = 7 days;

    uint256 weightedReward;
    uint256 totalStaked;
    uint256 adminFeePercent;
    uint256 adminFeeAmount;
    uint256 totalReward;

    uint256 public constant MAX_TOTAL_WEIGHT = 1e36;

    mapping(address => uint256) userCollectedReward;
    mapping(address => uint256) userReward;

    // Define events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount);
    event LiquidityTransferred(address indexed user, uint256 amount);

    constructor(uint256 _adminFeePercent) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDITY_MANAGER_ROLE, msg.sender);
        adminFeePercent = _adminFeePercent;
    }

    function changeLiquidityManager(address newManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(LIQUIDITY_MANAGER_ROLE, msg.sender);
        _grantRole(LIQUIDITY_MANAGER_ROLE, newManager);
    }

    function stake() external payable nonReentrant {
        require(msg.value > 0, "Cannot stake 0 ETH");

        updateReward();

        uint256 curTotalStaked = totalStaked + msg.value;
        stakedBalances[msg.sender] += msg.value;
        totalStaked = curTotalStaked;

        // Emit Staked event
        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 _amount) external nonReentrant {
        require(stakedBalances[msg.sender] >= _amount, "Insufficient staked balance");

        updateReward();

        unstakeTimestamps[msg.sender] = block.timestamp;
        stakedBalances[msg.sender] -= _amount;
        totalStaked -= _amount;

        // Emit Unstaked event
        emit Unstaked(msg.sender, _amount, block.timestamp);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(block.timestamp >= unstakeTimestamps[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not yet passed");
        payable(msg.sender).transfer(_amount);

        // Emit Withdrawn event
        emit Withdrawn(msg.sender, _amount);
    }

    function addBridgeFee() external payable onlyRole(LIQUIDITY_MANAGER_ROLE) {
        uint256 currentReward = msg.value;

        uint256 adminFees = (currentReward * adminFeePercent) / 100000;
        adminFeeAmount += adminFees;
        currentReward -= adminFees;

        totalReward += currentReward;
    }

    function transferLiquidity(address _to, uint256 _amount) external nonReentrant onlyRole(LIQUIDITY_MANAGER_ROLE) {
        require(address(this).balance >= _amount, "Insufficient contract balance");
        payable(_to).transfer(_amount);

        // Emit LiquidityTransferred event
        emit LiquidityTransferred(_to, _amount);
    }

    function fund() public payable nonReentrant onlyRole(LIQUIDITY_MANAGER_ROLE) returns (bool success) {
        return true;
    }

    function updateReward() public {
        if (totalStaked == 0) return;

        address user = msg.sender;
        uint256 currentUserReward = (weightedReward - userCollectedReward[user]) * stakedBalances[user];
        userReward[user] += currentUserReward;
        userCollectedReward[user] = weightedReward;

        weightedReward += (totalReward * MAX_TOTAL_WEIGHT) / totalStaked;
        totalReward = 0;
    }

    function checkRewardForUser(address user) public view returns (uint256) {
        uint256 currentUserReward = userReward[user];
        currentUserReward /= MAX_TOTAL_WEIGHT;
        return currentUserReward;
    }

    function getRewardForUser() external nonReentrant {
        updateReward();

        address user = msg.sender;
        uint256 currentUserReward = userReward[user];
        if (currentUserReward == 0) return;
        currentUserReward /= MAX_TOTAL_WEIGHT;
        payable(msg.sender).transfer(currentUserReward);
        userReward[user] = 0;
    }
}
