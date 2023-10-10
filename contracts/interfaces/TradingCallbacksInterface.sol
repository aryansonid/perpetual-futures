// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface TradingCallbacksInterface {
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
    struct TradeData {
        uint40 maxSlippageP; // 1e10 (%)
        uint216 _placeholder; // for potential future data
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

    function setTradeData(
        SimplifiedTradeId calldata,
        TradeData memory
    ) external;

    function canExecuteTimeout() external view returns (uint);

    function pairMaxLeverage(uint) external view returns (uint);
}
