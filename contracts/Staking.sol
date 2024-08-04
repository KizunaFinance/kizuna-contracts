// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol"; // Import Pausable
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interface/IStakingBridge.sol";

contract Staking is AccessControl, ReentrancyGuard, Pausable {
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

    IStakingBridge public StakingBridge; // Add public visibility

    // Define events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount);
    event LiquidityTransferred(address indexed user, uint256 amount);
    event SetStakingBridge(IStakingBridge _stakingBridge);
    event SetLiquidityManager(address _newManager);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDITY_MANAGER_ROLE, msg.sender);
    }

    function setLiquidityManager(address _newManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newManager != address(0), "Invalid address"); // Add validation
        _grantRole(LIQUIDITY_MANAGER_ROLE, _newManager);
        emit SetLiquidityManager(_newManager);
    }

    function setStakingBridge(IStakingBridge _stakingBridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(_stakingBridge) != address(0), "Invalid address"); // Add validation
        StakingBridge = _stakingBridge;
        emit SetStakingBridge(_stakingBridge);
    }

    function stake() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Cannot stake 0 ETH");

        stakedBalances[msg.sender] += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 _amount) external nonReentrant whenNotPaused {
        require(stakedBalances[msg.sender] >= _amount, "Insufficient staked balance");

        stakedBalances[msg.sender] -= _amount;

        uint256 lastClaimID = LAST_CLAIM_ID;

        withdrawClaims[lastClaimID] = WithdrawClaim(msg.sender, block.timestamp, _amount);
        ++LAST_CLAIM_ID;

        emit Unstaked(msg.sender, _amount, block.timestamp);
    }

    function withdraw(uint256 recordID) external nonReentrant whenNotPaused {
        require(
            block.timestamp >= withdrawClaims[recordID].timestamp + COOLDOWN_PERIOD,
            "Cooldown period not yet passed"
        );
        require(withdrawClaims[recordID].withdrawer == msg.sender, "Not withdrawer");
        require(address(this).balance >= withdrawClaims[recordID].amount, "Not enough balance for withdrawal");

        payable(msg.sender).transfer(withdrawClaims[recordID].amount);

        emit Withdrawn(msg.sender, withdrawClaims[recordID].amount);

        delete withdrawClaims[recordID];
    }

    function withdrawByBridge(
        uint256 recordID,
        uint32 _dstEid,
        address recvAddress,
        bytes calldata _options
    ) external payable nonReentrant whenNotPaused {
        require(
            block.timestamp >= withdrawClaims[recordID].timestamp + COOLDOWN_PERIOD,
            "Cooldown period not yet passed"
        );

        require(withdrawClaims[recordID].withdrawer == msg.sender, "Not withdrawer");

        StakingBridge.send{ value: msg.value }(_dstEid, withdrawClaims[recordID].amount, recvAddress, _options);

        emit Withdrawn(msg.sender, withdrawClaims[recordID].amount);

        delete withdrawClaims[recordID];
    }

    function fund() public payable nonReentrant onlyRole(LIQUIDITY_MANAGER_ROLE) returns (bool success) {
        return true;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    receive() external payable {} // Add receive function
}
