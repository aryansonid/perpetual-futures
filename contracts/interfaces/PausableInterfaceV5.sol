// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {StorageInterface} from "./StorageInterface.sol";

interface PausableInterfaceV5 {
    function isPaused() external view returns (bool);

    function isTradeParLiquidatablePure(
        StorageInterface.Trade memory t
    ) external view returns (bool, bool);

    function isTradeLiquidatablePure(
        StorageInterface.Trade memory t
    ) external view returns (bool, bool);

    function executeNftOrders(
        uint[100] memory _orderTypes,
        address[100] memory traders,
        uint[100] memory pairIndexs,
        uint[100] memory index
    ) external;
}
