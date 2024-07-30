// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IStakingBridge.sol";
import "hardhat/console.sol";

contract Staking is AccessControl, ReentrancyGuard {
    bytes32 public constant LIQUIDITY_MANAGER_ROLE = keccak256("LIQUIDITY_MANAGER_ROLE");

    struct WithdrawClaim {
        address withdrawer;
        uint256 timestamp;
        uint256 amount;
    }
    mapping(address => uint256) public stakedBalances;
    mapping(uint256 => WithdrawClaim) public withdrawClaims;
    uint256 public LAST_CLAIM_ID;
    uint256 public constant COOLDOWN_PERIOD = 7 days;

    uint256 weightedReward;
    uint256 totalStaked;
    uint256 adminFeePercent;
    uint256 adminFeeAmount;
    uint256 totalReward;

    IStakingBridge StakingBridge;

    uint256 public constant MAX_TOTAL_WEIGHT = 1e36;

    mapping(address => uint256) userCollectedReward;
    mapping(address => uint256) userReward;

    // Define events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount);
    event LiquidityTransferred(address indexed user, uint256 amount);
    event SetStakingBridge(IStakingBridge _stakingBridge);
    event SetLiquidityManager(address _newManager);

    constructor(uint256 _adminFeePercent) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDITY_MANAGER_ROLE, msg.sender);
        adminFeePercent = _adminFeePercent;
    }

    function setLiquidityManager(address _newManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(LIQUIDITY_MANAGER_ROLE, _newManager);
        emit SetLiquidityManager(_newManager);
    }

    function setStakingBridge(IStakingBridge _stakingBridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        StakingBridge = _stakingBridge;
        emit SetStakingBridge(_stakingBridge);
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

        stakedBalances[msg.sender] -= _amount;
        totalStaked -= _amount;
        uint256 lastClaimID = LAST_CLAIM_ID;
        withdrawClaims[lastClaimID] = WithdrawClaim(msg.sender, block.timestamp, _amount);
        LAST_CLAIM_ID = lastClaimID + 1;

        // Emit Unstaked event
        emit Unstaked(msg.sender, _amount, block.timestamp);
    }

    function withdraw(uint256 recordID) external nonReentrant {
        require(
            block.timestamp >= withdrawClaims[recordID].timestamp + COOLDOWN_PERIOD,
            "Cooldown period not yet passed"
        );
        require(withdrawClaims[recordID].withdrawer == msg.sender, "not withdrawer");
        payable(msg.sender).transfer(withdrawClaims[recordID].amount);

        // Emit Withdrawn event
        emit Withdrawn(msg.sender, withdrawClaims[recordID].amount);

        delete withdrawClaims[recordID];
    }

    function withdrawByBridge(
        uint256 recordID,
        uint32 _dstEid,
        address recvAddress,
        bytes calldata _options
    ) external payable nonReentrant {
        console.log("withdraw claims:", withdrawClaims[recordID].timestamp);

        require(
            block.timestamp >= withdrawClaims[recordID].timestamp + COOLDOWN_PERIOD,
            "Cooldown period not yet passed"
        );
        require(withdrawClaims[recordID].withdrawer == msg.sender, "not withdrawer");
        require(address(this).balance < withdrawClaims[recordID].amount, "enough for direct withdraw");
        // payable(msg.sender).transfer(withdrawClaims[recordID].amount);

        console.log("staking bridge:", address(StakingBridge));
        address ethVault = StakingBridge.ethVault();
        console.log("ethVault:", ethVault);
        StakingBridge.send{ value: msg.value }(_dstEid, withdrawClaims[recordID].amount, recvAddress, _options);

        // Emit Withdrawn event
        emit Withdrawn(msg.sender, withdrawClaims[recordID].amount);

        delete withdrawClaims[recordID];
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
