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

    IStakingBridge public StakingBridge;

    // Define events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp, uint256 recordID);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawnByBridge(address indexed user, uint256 amount, uint32 dstEid, address recvAddress);
    event LiquidityTransferred(address indexed user, uint256 amount);
    event SetStakingBridge(IStakingBridge _stakingBridge);
    event SetLiquidityManager(address _newManager);

    mapping(address => uint256[]) public userClaims; // New mapping to store user claims

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDITY_MANAGER_ROLE, msg.sender);
    }

    /**
     * @notice Set a new liquidity manager
     * @param _newManager The address of the new liquidity manager
     */
    function setLiquidityManager(address _newManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newManager != address(0), "Invalid address"); // Add validation
        _grantRole(LIQUIDITY_MANAGER_ROLE, _newManager);
        emit SetLiquidityManager(_newManager);
    }

    /**
     * @notice Set the staking bridge contract
     * @param _stakingBridge The address of the staking bridge contract
     */
    function setStakingBridge(IStakingBridge _stakingBridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(_stakingBridge) != address(0), "Invalid address"); // Add validation
        StakingBridge = _stakingBridge;
        emit SetStakingBridge(_stakingBridge);
    }

    /**
     * @notice Stake ETH into the contract
     */
    function stake() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Cannot stake 0 ETH");

        stakedBalances[msg.sender] += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    /**
     * @notice Unstake a specified amount of ETH
     * @param _amount The amount of ETH to unstake
     */
    function unstake(uint256 _amount) external nonReentrant whenNotPaused {
        require(stakedBalances[msg.sender] >= _amount, "Insufficient staked balance");

        stakedBalances[msg.sender] -= _amount;

        uint256 lastClaimID = LAST_CLAIM_ID;

        withdrawClaims[lastClaimID] = WithdrawClaim(msg.sender, block.timestamp, _amount);
        userClaims[msg.sender].push(lastClaimID); // Record the claim ID for the user
        ++LAST_CLAIM_ID;

        emit Unstaked(msg.sender, _amount, block.timestamp, lastClaimID);
    }

    /**
     * @notice Get the list of claim IDs for a user
     * @param user The address of the user
     * @return An array of claim IDs
     */
    function getUserClaims(address user) external view returns (uint256[] memory) {
        return userClaims[user];
    }

    /**
     * @notice Withdraw a specified claim after the cooldown period
     * @param recordID The ID of the claim to withdraw
     */
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

    /**
     * @notice Withdraw a specified claim via the staking bridge after the cooldown period
     * @param recordID The ID of the claim to withdraw
     * @param _dstEid The destination chain ID
     * @param recvAddress The address to receive the funds on the destination chain
     * @param _options Additional options for the bridge transfer
     */
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

        emit WithdrawnByBridge(msg.sender, withdrawClaims[recordID].amount, _dstEid, recvAddress);

        delete withdrawClaims[recordID];
    }

    /**
     * @notice Transfer liquidity to a specified address
     * @param _to The address to transfer liquidity to
     * @param _amount The amount of liquidity to transfer
     */
    function transferLiquidity(address _to, uint256 _amount) external onlyRole(LIQUIDITY_MANAGER_ROLE) {
        payable(_to).transfer(_amount);
        emit LiquidityTransferred(_to, _amount);
    }

    /**
     * @notice Fund the contract with ETH
     * @return success A boolean indicating success
     */
    function fund() public payable nonReentrant onlyRole(LIQUIDITY_MANAGER_ROLE) returns (bool success) {
        return true;
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Receive function to accept ETH
     */
    receive() external payable {} // Add receive function
}
