// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt, MessagingParams } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import "./interface/IStaking.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract KizunaBridge is OApp, Pausable, ReentrancyGuard {
    event SetEthVaultAddress(address ethVault);
    event WithdrawAdminFees(address to, uint256 amount);
    event FallbackCalled(address sender, uint256 value);
    event Received(address sender, uint256 value);
    event SendAmount(address sender, uint256 amount, address recvAddress, MessagingReceipt receipt);
    event ReceivedAmount(uint256 recvAmount, address recvAddress);
    event SetBridgeFeesPercent(uint256 bridgeFeesPercent);

    IStaking public ethVault;
    uint256 public bridgeFeesPercent;
    uint256 public adminAmount;

    // Define minimum amount as a constant
    uint256 public constant MIN_AMOUNT = 100000;

    /**
     * @notice Constructor to initialize the KizunaBridge contract.
     * @param _endpoint The endpoint address.
     * @param _delegate The delegate address.
     * @param _feesPercent The percentage of fees for the bridge.
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
    function withdrawAdminFees(address payable to) external onlyOwner nonReentrant {
        require(adminAmount > 0, "No admin fees to withdraw");
        to.transfer(adminAmount);
        emit WithdrawAdminFees(to, adminAmount);
        adminAmount = 0;
    }

    /**
     * @notice Sends a message from the source chain to a destination chain.
     * @param _dstEid The endpoint ID of the destination chain.
     * @param fee The fee for sending the message.
     * @param recvAddress The address to receive the amount on the destination chain.
     * @param _options Additional options for message execution.
     * @return receipt A `MessagingReceipt` struct containing details of the message sent.
     */
    function sendAmount(
        uint32 _dstEid,
        uint256 fee,
        address recvAddress,
        bytes calldata _options
    ) external payable whenNotPaused nonReentrant returns (MessagingReceipt memory receipt) {
        uint256 amount = msg.value - fee;
        require(amount > MIN_AMOUNT, "Amount must be greater than minimum required");
        uint256 bridgeFee = (amount * bridgeFeesPercent) / 100000;
        amount -= bridgeFee;
        adminAmount += bridgeFee;

        bytes memory _payload = abi.encode(amount, recvAddress);
        receipt = endpoint.send{ value: fee }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _payload, _options, false),
            payable(msg.sender)
        );

        ethVault.fund{ value: amount }();
        emit SendAmount(msg.sender, amount, recvAddress, receipt);
    }

    /**
     * @notice Quotes the fee for sending an amount message.
     * @param _dstEid The endpoint ID of the destination chain.
     * @param amount The amount to be sent.
     * @param recvAddress The address to receive the amount on the destination chain.
     * @param _options Additional options for message execution.
     * @return fee A `MessagingFee` struct containing the fee details.
     */
    function quoteAmount(
        uint32 _dstEid,
        uint256 amount,
        address recvAddress,
        bytes memory _options
    ) public view returns (MessagingFee memory fee) {
        bytes memory _payload = abi.encode(amount, recvAddress);
        fee = _quote(_dstEid, _payload, _options, false);
    }

    /**
     * @dev Internal function override to handle incoming messages from another chain.
     * @param payload The encoded message payload being received.
     * Decodes the received payload and processes it as per the business logic defined in the function.
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        uint256 recvAmount;
        address recvAddress;
        (recvAmount, recvAddress) = abi.decode(payload, (uint256, address));
        if (address(ethVault).balance < recvAmount) {
            revert("Insufficient balance in vault");
        }
        ethVault.transferLiquidity(recvAddress, recvAmount);
        emit ReceivedAmount(recvAmount, recvAddress);
    }

    /**
     * @notice Fallback function to handle incoming ether.
     */
    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.value);
    }

    /**
     * @notice Receive function to handle incoming ether.
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
