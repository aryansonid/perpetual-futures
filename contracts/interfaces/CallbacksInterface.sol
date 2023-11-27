// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./StorageInterface.sol";

interface CallbacksInterface {
    struct AggregatorAnswer {
        uint orderId;
        uint price;
        uint spreadP;
        uint open;
        uint high;
        uint low;
    }

    // struct PendingMarketOrder {
    //     Trade trade;
    //     uint block;
    //     uint wantedPrice; // PRECISION
    //     uint slippageP; // PRECISION (%)
    //     uint spreadReductionP;
    //     uint tokenId; // index in supportedTokens
    // }

    // struct Trade {
    //     address trader;
    //     uint pairIndex;
    //     uint index;
    //     uint initialPosToken; // 1e18
    //     uint positionSizeWETH; // 1e18
    //     uint openPrice; // PRECISION
    //     bool buy;
    //     uint leverage;
    //     uint tp; // PRECISION
    //     uint sl; // PRECISION
    // }

    function openTradeMarketCallback(
        AggregatorAnswer memory a,
        StorageInterface.PendingMarketOrder memory o
    ) external;

    function closeTradeMarketCallback(
        AggregatorAnswer memory a,
        StorageInterface.PendingMarketOrder memory o
    ) external;

    function executeNftOpenOrderCallback(
        AggregatorAnswer memory a,
        StorageInterface.PendingNftOrder memory o
    ) external;

    function executeNftCloseOrderCallback(
        AggregatorAnswer memory,
        StorageInterface.PendingNftOrder memory o
    ) external;

    function getTradePnl(
        address trader,
        uint pairIndex,
        uint index
    ) external view returns (int256 pnl);
}
