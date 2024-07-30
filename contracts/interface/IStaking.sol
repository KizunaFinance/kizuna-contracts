// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStaking {
    struct WithdrawClaim {
        address withdrawer;
        uint256 timestamp;
        uint256 amount;
    }

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount);
    event LiquidityTransferred(address indexed user, uint256 amount);
    event SetLiquidityManager(address _newManager);

    function LIQUIDITY_MANAGER_ROLE() external view returns (bytes32);
    function stakedBalances(address) external view returns (uint256);
    function withdrawClaims(uint256) external view returns (WithdrawClaim memory);
    function LAST_CLAIM_ID() external view returns (uint256);
    function COOLDOWN_PERIOD() external view returns (uint256);
    function MAX_TOTAL_WEIGHT() external view returns (uint256);

    function setLiquidityManager(address _newManager) external;
    function stake() external payable;
    function unstake(uint256 _amount) external;
    function withdraw(uint256 recordID) external;
    function withdrawByBridge(
        uint256 recordID,
        uint32 _dstEid,
        address recvAddress,
        bytes calldata _options
    ) external payable;
    function addBridgeFee() external payable;
    function transferLiquidity(address _to, uint256 _amount) external;
    function fund() external payable returns (bool success);
    function updateReward() external;
    function checkRewardForUser(address user) external view returns (uint256);
    function getRewardForUser() external;
}
