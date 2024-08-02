// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt, MessagingParams } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import "./interface/IStaking.sol";
import "hardhat/console.sol";

contract StakingBridge is OApp {
    // emit AddedNativeTokens(address owner, uint256 amt);
    event ReceiveEvent(uint256 recvAmount, address recvAddress);
    event SetEthVaultAddress(address ethVault);

    IStaking public ethVault;
    uint256 bridgeFeesPercent;

    constructor(
        address _endpoint,
        address _delegate,
        uint256 _feesPercent,
        IStaking _ethVault
    ) OApp(_endpoint, _delegate) Ownable(_delegate) {
        bridgeFeesPercent = _feesPercent;
        ethVault = _ethVault;
    }

    function setEthVaultAddress(address _ethVault) external onlyOwner {
        ethVault = IStaking(_ethVault);
        emit SetEthVaultAddress(_ethVault);
    }

    /**
     * @notice Sends a message from the source chain to a destination chain.
     * @param _dstEid The endpoint ID of the destination chain.
     * @param stakingAmount The message string to be sent.
     * @param _options Additional options for message execution.
     * @dev Encodes the message as bytes and sends it using the `_lzSend` internal function.
     * @return receipt A `MessagingReceipt` struct containing details of the message sent.
     */
    function send(
        uint32 _dstEid,
        uint256 stakingAmount,
        address recvAddress,
        bytes calldata _options
    ) external payable returns (MessagingReceipt memory receipt) {
        require(msg.sender == address(ethVault), "only callable by ethVault");
        uint256 bridgeFee = (msg.value * bridgeFeesPercent) / 100000;
        ethVault.addBridgeFee{ value: bridgeFee }();

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
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(0, msg.sender);
        fee = _quote(_dstEid, payload, _options, _payInLzToken);
    }

    /**
     * @dev Internal function override to handle incoming messages from another chain.
     * @dev _origin A struct containing information about the message sender.
     * @dev _guid A unique global packet identifier for the message.
     * @param payload The encoded message payload being received.
     *
     * @dev The following params are unused in the current implementation of the OApp.
     * @dev _executor The address of the Executor responsible for processing the message.
     * @dev _extraData Arbitrary data appended by the Executor to the message.
     *
     * Decodes the received payload and processes it as per the business logic defined in the function.
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        uint256 recvAmount;
        address recvAddress;
        (recvAmount, recvAddress) = abi.decode(payload, (uint256, address));

        ethVault.transferLiquidity(recvAddress, recvAmount);

        emit ReceiveEvent(recvAmount, recvAddress);
    }

    fallback() external payable onlyOwner {}

    receive() external payable {}
}
