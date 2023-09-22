// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interfaces/StorageInterface.sol";
import "../interfaces/TradingCallbacksInterface.sol";

library TradeUtils {
    function _getTradeLastUpdated(
        address _callbacks,
        address trader,
        uint pairIndex,
        uint index,
        TradingCallbacksInterface.TradeType _type
    )
        internal
        view
        returns (
            TradingCallbacksInterface,
            TradingCallbacksInterface.LastUpdated memory,
            TradingCallbacksInterface.SimplifiedTradeId memory
        )
    {
        TradingCallbacksInterface callbacks = TradingCallbacksInterface(
            _callbacks
        );
        TradingCallbacksInterface.LastUpdated memory l = callbacks
            .tradeLastUpdated(trader, pairIndex, index, _type);

        return (
            callbacks,
            l,
            TradingCallbacksInterface.SimplifiedTradeId(
                trader,
                pairIndex,
                index,
                _type
            )
        );
    }

    function setTradeLastUpdated(
        address _callbacks,
        address trader,
        uint pairIndex,
        uint index,
        TradingCallbacksInterface.TradeType _type,
        uint blockNumber
    ) external {
        uint32 b = uint32(blockNumber);
        TradingCallbacksInterface callbacks = TradingCallbacksInterface(
            _callbacks
        );
        callbacks.setTradeLastUpdated(
            TradingCallbacksInterface.SimplifiedTradeId(
                trader,
                pairIndex,
                index,
                _type
            ),
            TradingCallbacksInterface.LastUpdated(b, b, b, b)
        );
    }

    function setSlLastUpdated(
        address _callbacks,
        address trader,
        uint pairIndex,
        uint index,
        TradingCallbacksInterface.TradeType _type,
        uint blockNumber
    ) external {
        (
            TradingCallbacksInterface callbacks,
            TradingCallbacksInterface.LastUpdated memory l,
            TradingCallbacksInterface.SimplifiedTradeId memory id
        ) = _getTradeLastUpdated(_callbacks, trader, pairIndex, index, _type);

        l.sl = uint32(blockNumber);
        callbacks.setTradeLastUpdated(id, l);
    }

    function setTpLastUpdated(
        address _callbacks,
        address trader,
        uint pairIndex,
        uint index,
        TradingCallbacksInterface.TradeType _type,
        uint blockNumber
    ) external {
        (
            TradingCallbacksInterface callbacks,
            TradingCallbacksInterface.LastUpdated memory l,
            TradingCallbacksInterface.SimplifiedTradeId memory id
        ) = _getTradeLastUpdated(_callbacks, trader, pairIndex, index, _type);

        l.tp = uint32(blockNumber);
        callbacks.setTradeLastUpdated(id, l);
    }

    function isTpInTimeout(
        address _callbacks,
        TradingCallbacksInterface.SimplifiedTradeId memory id,
        uint currentBlock
    ) external view returns (bool) {
        (
            TradingCallbacksInterface callbacks,
            TradingCallbacksInterface.LastUpdated memory l,

        ) = _getTradeLastUpdated(
                _callbacks,
                id.trader,
                id.pairIndex,
                id.index,
                id.tradeType
            );

        return currentBlock < uint256(l.tp) + callbacks.canExecuteTimeout();
    }

    function isSlInTimeout(
        address _callbacks,
        TradingCallbacksInterface.SimplifiedTradeId memory id,
        uint currentBlock
    ) external view returns (bool) {
        (
            TradingCallbacksInterface callbacks,
            TradingCallbacksInterface.LastUpdated memory l,

        ) = _getTradeLastUpdated(
                _callbacks,
                id.trader,
                id.pairIndex,
                id.index,
                id.tradeType
            );

        return currentBlock < uint256(l.sl) + callbacks.canExecuteTimeout();
    }

    function isLimitInTimeout(
        address _callbacks,
        TradingCallbacksInterface.SimplifiedTradeId memory id,
        uint currentBlock
    ) external view returns (bool) {
        (
            TradingCallbacksInterface callbacks,
            TradingCallbacksInterface.LastUpdated memory l,

        ) = _getTradeLastUpdated(
                _callbacks,
                id.trader,
                id.pairIndex,
                id.index,
                id.tradeType
            );

        return currentBlock < uint256(l.limit) + callbacks.canExecuteTimeout();
    }

    function setTradeData(
        address _callbacks,
        address trader,
        uint pairIndex,
        uint index,
        TradingCallbacksInterface.TradeType _type,
        uint maxSlippageP
    ) external {
        require(maxSlippageP <= type(uint40).max, "OVERFLOW");
        TradingCallbacksInterface callbacks = TradingCallbacksInterface(
            _callbacks
        );
        callbacks.setTradeData(
            TradingCallbacksInterface.SimplifiedTradeId(
                trader,
                pairIndex,
                index,
                _type
            ),
            TradingCallbacksInterface.TradeData(uint40(maxSlippageP), 0)
        );
    }
}
