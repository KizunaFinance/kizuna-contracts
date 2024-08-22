// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt, MessagingParams } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import "./interface/IStaking.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract GenericBridge is OApp, Pausable, ReentrancyGuard {
    event WithdrawAdminFees(address to, uint256 amount);
    event FallbackCalled(address sender, uint256 value);
    event Received(address sender, uint256 value);
    event SendAmount(address sender, address to, bytes data, MessagingReceipt receipt);
    event ReceivedAmount(uint256 recvAmount, address recvAddress);

    // Define minimum amount as a constant
    uint256 public constant MIN_AMOUNT = 100000;

    constructor(address _endpoint, address _delegate) OApp(_endpoint, _delegate) Ownable(_delegate) {}

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

    function sendAmount(
        uint32 _dstEid,
        uint256 fee,
        address to,
        bytes memory data,
        bytes calldata _options
    ) external payable whenNotPaused nonReentrant returns (MessagingReceipt memory receipt) {
        bytes memory _payload = abi.encode(to, data);
        receipt = endpoint.send{ value: fee }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _payload, _options, false),
            payable(msg.sender)
        );

        emit SendAmount(msg.sender, to, data, receipt);
    }

    function quoteAmount(
        uint32 _dstEid,
        address to,
        bytes memory data,
        bytes memory _options
    ) public view returns (MessagingFee memory fee) {
        bytes memory _payload = abi.encode(to, data);
        fee = _quote(_dstEid, _payload, _options, false);
    }

    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        address to;
        bytes memory data;

        (to, data) = abi.decode(payload, (address, bytes));

        bool success;
        (success, ) = to.call(data);
        if (!success) {
            revert("Call failed");
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
