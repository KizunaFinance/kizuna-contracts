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
    event RefundedAmount(bytes32 guid, address sender, uint256 amount);
    event SetBridgeFeesPercent(uint256 bridgeFeesPercent);

    uint256 public constant BRIDGE_TYPE_AMOUNT = 0;
    uint256 public constant BRIDGE_TYPE_UNRECIEVED = 1;
    IStaking public ethVault;
    uint256 public bridgeFeesPercent;
    uint256 public adminAmount;

    struct SentAmount {
        address sender;
        uint256 amount;
    }
    mapping(bytes32 => SentAmount) public amountMap;

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

        bytes memory _payload = abi.encode(BRIDGE_TYPE_AMOUNT, amount, recvAddress);
        receipt = endpoint.send{ value: fee }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _payload, _options, false),
            payable(msg.sender)
        );
        amountMap[receipt.guid] = SentAmount({ sender: msg.sender, amount: amount });

        ethVault.fund{ value: amount }();
        emit SendAmount(msg.sender, amount, recvAddress, receipt);
    }

    /**
     * @notice Sends a message for unreceived amounts from the source chain to a destination chain.
     * @param _dstEid The endpoint ID of the destination chain.
     * @param guid The unique identifier for the message.
     * @param _options Additional options for message execution.
     * @return receipt A `MessagingReceipt` struct containing details of the message sent.
     */
    function sendUnrecieved(
        uint32 _dstEid,
        bytes32 guid,
        bytes calldata _options
    ) external payable whenNotPaused nonReentrant returns (MessagingReceipt memory receipt) {
        if (amountMap[guid].sender != address(0)) {
            revert("Amount has already been received");
        }
        bytes memory _payload = abi.encode(BRIDGE_TYPE_UNRECIEVED, guid);
        receipt = endpoint.send{ value: msg.value }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _payload, _options, false),
            payable(msg.sender)
        );
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
        bytes memory _payload = abi.encode(BRIDGE_TYPE_AMOUNT, amount, recvAddress);
        fee = _quote(_dstEid, _payload, _options, false);
    }

    /**
     * @notice Quotes the fee for sending an unreceived message.
     * @param _dstEid The endpoint ID of the destination chain.
     * @param guid The unique identifier for the message.
     * @param _options Additional options for message execution.
     * @return fee A `MessagingFee` struct containing the fee details.
     */
    function quoteUnrecieved(
        uint32 _dstEid,
        bytes32 guid,
        bytes memory _options
    ) public view returns (MessagingFee memory fee) {
        bytes memory _payload = abi.encode(BRIDGE_TYPE_UNRECIEVED, guid);
        fee = _quote(_dstEid, _payload, _options, false);
    }

    /**
     * @dev Internal function override to handle incoming messages from another chain.
     * @param payload The encoded message payload being received.
     * @param _guid A unique global packet identifier for the message.
     * Decodes the received payload and processes it as per the business logic defined in the function.
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 _guid,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        uint256 bridgeType = abi.decode(payload, (uint256));

        if (bridgeType == BRIDGE_TYPE_AMOUNT) {
            uint256 recvAmount;
            address recvAddress;
            (bridgeType, recvAmount, recvAddress) = abi.decode(payload, (uint256, uint256, address));
            if (address(ethVault).balance < recvAmount) {
                revert("Insufficient balance in vault");
            }
            ethVault.transferLiquidity(recvAddress, recvAmount);
            amountMap[_guid] = SentAmount({ sender: recvAddress, amount: recvAmount });
            emit ReceivedAmount(recvAmount, recvAddress);
        } else if (bridgeType == BRIDGE_TYPE_UNRECIEVED) {
            bytes32 guid;
            (bridgeType, guid) = abi.decode(payload, (uint256, bytes32));
            if (amountMap[guid].sender == address(0)) {
                revert("guid not found or already refunded");
            }

            ethVault.transferLiquidity(amountMap[guid].sender, amountMap[guid].amount);
            delete amountMap[guid];
            emit RefundedAmount(guid, amountMap[guid].sender, amountMap[guid].amount);
        }
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
