// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";

interface IDaikoBridge {
    event ReceiveEvent(uint256 recvAmount, address recvAddress);

    function ethVault() external view returns (address);
    function bridgeFeesPercent() external view returns (uint256);

    function send(
        uint32 _dstEid,
        uint256 fee,
        address recvAddress,
        bytes calldata _options
    ) external payable returns (MessagingReceipt memory receipt);

    function quote(
        uint32 _dstEid,
        bytes memory _options,
        bool _payInLzToken
    ) external view returns (MessagingFee memory fee);

    // Note: fallback and receive functions are not included in interfaces
}
