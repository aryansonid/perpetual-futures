// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface TradingCallbacksV6_3_1 {
    enum TradeType {
        MARKET,
        LIMIT
    }
    struct SimplifiedTradeId {
        address trader;
        uint pairIndex;
        uint index;
        TradeType tradeType;
    }
    struct LastUpdated {
        uint32 tp;
        uint32 sl;
        uint32 limit;
        uint32 created;
    }

    function tradeLastUpdated(
        address,
        uint,
        uint,
        TradeType
    ) external view returns (LastUpdated memory);

    function setTradeLastUpdated(
        SimplifiedTradeId calldata,
        LastUpdated memory
    ) external;

    function canExecuteTimeout() external view returns (uint);
}
