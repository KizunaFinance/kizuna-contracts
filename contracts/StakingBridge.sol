// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt, MessagingParams } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import "./interface/IStaking.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract StakingBridge is OApp, Pausable, ReentrancyGuard {
    event ReceiveEvent(uint256 recvAmount, address recvAddress);
    event SetEthVaultAddress(address ethVault);
    event WithdrawAdminFees(address to, uint256 amount);
    event SetBridgeFeesPercent(uint256 bridgeFeesPercent);

    IStaking public ethVault;
    uint256 public bridgeFeesPercent;
    uint256 public adminAmount;

    uint256 private constant FEE_DIVISOR = 100000;

    /**
     * @notice Constructor to initialize the StakingBridge contract.
     * @param _endpoint The endpoint address.
     * @param _delegate The delegate address.
     * @param _feesPercent The initial bridge fees percent.
     * @param _ethVault The address of the ETH vault.
     */
    constructor(
        address _endpoint,
        address _delegate,
        uint256 _feesPercent,
        IStaking _ethVault
    ) OApp(_endpoint, _delegate) Ownable(_delegate) {
        bridgeFeesPercent = _feesPercent;
        ethVault = _ethVault;
    }

    /**
     * @notice Sets the bridge fees percent.
     * @param _feesPercent The new bridge fees percent.
     */
    function setBridgeFeesPercent(uint256 _feesPercent) external onlyOwner {
        bridgeFeesPercent = _feesPercent;
        emit SetBridgeFeesPercent(_feesPercent);
    }

    /**
     * @notice Sets the ETH vault address.
     * @param _ethVault The new ETH vault address.
     */
    function setEthVaultAddress(address _ethVault) external onlyOwner {
        ethVault = IStaking(_ethVault);
        emit SetEthVaultAddress(_ethVault);
    }

    /**
     * @notice Pauses the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Allows the owner to withdraw accumulated admin fees.
     * @param to The address to send the withdrawn fees to.
     */
    function withdrawAdminFees(address payable to) external onlyOwner nonReentrant whenNotPaused {
        require(adminAmount > 0, "No admin fees to withdraw");
        uint256 amountToWithdraw = adminAmount;
        adminAmount = 0;
        to.transfer(amountToWithdraw);
        emit WithdrawAdminFees(to, amountToWithdraw);
    }

    /**
     * @notice Sends a message from the source chain to a destination chain.
     * @param _dstEid The endpoint ID of the destination chain.
     * @param stakingAmount The staking amount to be sent.
     * @param recvAddress The address to receive the staking amount.
     * @param _options Additional options for message execution.
     * @return receipt A `MessagingReceipt` struct containing details of the message sent.
     */
    function send(
        uint32 _dstEid,
        uint256 stakingAmount,
        address recvAddress,
        bytes calldata _options
    ) external payable whenNotPaused nonReentrant returns (MessagingReceipt memory receipt) {
        require(msg.sender == address(ethVault), "only callable by ethVault");
        uint256 bridgeFee = (msg.value * bridgeFeesPercent) / FEE_DIVISOR;
        adminAmount += bridgeFee;

        bytes memory _payload = abi.encode(stakingAmount, recvAddress);
        bytes32 peer = _getPeerOrRevert(_dstEid);

        receipt = endpoint.send{ value: msg.value - bridgeFee }( // solhint-disable-next-line check-send-result
            MessagingParams(_dstEid, peer, _payload, _options, false),
            payable(msg.sender)
        );
    }

    /**
     * @notice Quotes the gas needed to pay for the full omnichain transaction in native gas or ZRO token.
     * @param _dstEid Destination chain's endpoint ID.
     * @param _options Message execution options (e.g., for sending gas to destination).
     * @param _payInLzToken Whether to return fee in ZRO token.
     * @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quote(
        uint32 _dstEid,
        bytes calldata _options,
        bool _payInLzToken
    ) external view whenNotPaused returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(0, msg.sender);
        fee = _quote(_dstEid, payload, _options, _payInLzToken);
    }

    /**
     * @dev Internal function override to handle incoming messages from another chain.
     * @param payload The encoded message payload being received.
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override whenNotPaused nonReentrant {
        (uint256 recvAmount, address recvAddress) = abi.decode(payload, (uint256, address));
        ethVault.transferLiquidity(recvAddress, recvAmount);
        emit ReceiveEvent(recvAmount, recvAddress);
    }

    /**
     * @notice Fallback function to receive ETH.
     */
    fallback() external payable onlyOwner {}

    /**
     * @notice Receive function to receive ETH.
     */
    receive() external payable {}
}
