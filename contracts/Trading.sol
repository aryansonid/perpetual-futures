// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/StorageInterface.sol";
import "./interfaces/PairInfosInterface.sol";
import "./interfaces/ReferralsInterface.sol";
import "./interfaces/BorrowingFeesInterface.sol";
import "./Delegatable.sol";
import "./libraries/ChainUtils.sol";
import "./libraries/TradeUtils.sol";
import "./libraries/PackingUtils.sol";
import "./interfaces/NFTRewardInterfaceV6_3.sol";
import "./interfaces/CallbacksInterface.sol";
import "./interfaces/PairsStorageInterfaceV6.sol";
import "./interfaces/AggregatorInterfaceV1_4.sol";

contract Trading is Delegatable, Initializable {
    using TradeUtils for address;
    using PackingUtils for uint256;

    // Contracts (constant)
    StorageInterface public storageT;
    NftRewardsInterfaceV6_3_1 public nftRewards;
    PairInfosInterface public pairInfos;
    ReferralsInterface public referrals;
    BorrowingFeesInterface public borrowingFees;
    CallbacksInterface public callbacks;

    // Params (constant)
    uint constant PRECISION = 1e10;
    uint constant MAX_SL_P = 75; // -75% PNL

    // Params (adjustable)
    uint public maxPosWETH; // 1e18 (eg. 75000 * 1e18)
    uint public marketOrdersTimeout; // block (eg. 30)
    int public minLeveragedPosWETH; //100 weth

    // State
    bool public isPaused; // Prevent opening new trades
    bool public isDone; // Prevent any interaction with the contract

    // Events
    event Done(bool done);
    event MinLeveragedPosWETHSet(int value);
    event Paused(bool paused);

    event NumberUpdated(string name, uint value);

    event MarketOrderInitiated(
        uint indexed orderId,
        address indexed trader,
        uint indexed pairIndex,
        bool open
    );

    event OpenLimitPlaced(
        address indexed trader,
        uint indexed pairIndex,
        uint index
    );
    event OpenLimitUpdated(
        address indexed trader,
        uint indexed pairIndex,
        uint index,
        uint newPrice,
        uint newTp,
        uint newSl,
        uint maxSlippageP
    );
    event OpenLimitCanceled(
        address indexed trader,
        uint indexed pairIndex,
        uint index
    );

    event TpUpdated(
        address indexed trader,
        uint indexed pairIndex,
        uint index,
        uint newTp
    );
    event SlUpdated(
        address indexed trader,
        uint indexed pairIndex,
        uint index,
        uint newSl
    );

    event NftOrderInitiated(
        uint orderId,
        address indexed nftHolder,
        address indexed trader,
        uint indexed pairIndex
    );
    event NftOrderSameBlock(
        address indexed nftHolder,
        address indexed trader,
        uint indexed pairIndex
    );

    event ChainlinkCallbackTimeout(
        uint indexed orderId,
        StorageInterface.PendingMarketOrder order
    );
    event CouldNotCloseTrade(
        address indexed trader,
        uint indexed pairIndex,
        uint index
    );

    function initialize(
        StorageInterface _storageT,
        NftRewardsInterfaceV6_3_1 _nftRewards,
        PairInfosInterface _pairInfos,
        ReferralsInterface _referrals,
        BorrowingFeesInterface _borrowingFees,
        CallbacksInterface _callbacks,
        uint _maxPosWETH,
        uint _marketOrdersTimeout,
        int _minLeveragedPosWETH
    ) external initializer {
        require(
            address(_storageT) != address(0) &&
                address(_nftRewards) != address(0) &&
                address(_pairInfos) != address(0) &&
                address(_referrals) != address(0) &&
                address(_borrowingFees) != address(0) &&
                address(_callbacks) != address(0) &&
                _maxPosWETH > 0 &&
                _marketOrdersTimeout > 0,
            "WRONG_PARAMS"
        );

        storageT = _storageT;
        nftRewards = _nftRewards;
        pairInfos = _pairInfos;
        referrals = _referrals;
        borrowingFees = _borrowingFees;

        maxPosWETH = _maxPosWETH;
        marketOrdersTimeout = _marketOrdersTimeout;
        callbacks = _callbacks;
        minLeveragedPosWETH = _minLeveragedPosWETH;
    }

    // Modifiers
    modifier onlyGov() {
        isGov();
        _;
    }
    modifier notContract() {
        isNotContract();
        _;
    }
    modifier notDone() {
        isNotDone();
        _;
    }

    // Saving code size by calling these functions inside modifiers
    function isGov() private view {
        require(msg.sender == storageT.gov(), "GOV_ONLY");
    }

    function isNotContract() private view {
        require(tx.origin == msg.sender);
    }

    function isNotDone() private view {
        require(!isDone, "DONE");
    }

    // Manage params
    function setMaxPosWETH(uint value) external onlyGov {
        require(value > 0, "VALUE_0");
        maxPosWETH = value;
        emit NumberUpdated("maxPosWETH", value);
    }

    function setMarketOrdersTimeout(uint value) external onlyGov {
        require(value > 0, "VALUE_0");
        marketOrdersTimeout = value;
        emit NumberUpdated("marketOrdersTimeout", value);
    }

    function setMinLeveragedPosWETH(int value) external onlyGov {
        require(value > 0, "VALUE_0");
        minLeveragedPosWETH = value;
        emit MinLeveragedPosWETHSet(value);
    }

    // Manage state
    function pause() external onlyGov {
        isPaused = !isPaused;
        emit Paused(isPaused);
    }

    function done() external onlyGov {
        isDone = !isDone;
        emit Done(isDone);
    }

    // Open new trade (MARKET/LIMIT)
    function openTrade(
        StorageInterface.Trade memory t,
        NftRewardsInterfaceV6_3_1.OpenLimitOrderType orderType, // LEGACY => market
        uint spreadReductionId,
        uint slippageP // 1e10 (%)
    )
        external
        // address referrer
        notContract
        notDone
    {
        require(!isPaused, "PAUSED");
        require(t.openPrice * slippageP < type(uint256).max, "OVERFLOW");
        require(t.openPrice > 0, "PRICE_ZERO");

        AggregatorInterfaceV1_4 aggregator = AggregatorInterfaceV1_4(
            address(storageT.priceAggregator())
        );
        PairsStorageInterfaceV6 pairsStored = aggregator.pairsStorage();

        address sender = _msgSender();

        require(
            storageT.openTradesCount(sender, t.pairIndex) +
                storageT.pendingMarketOpenCount(sender, t.pairIndex) +
                storageT.openLimitOrdersCount(sender, t.pairIndex) <
                storageT.maxTradesPerPair(),
            "MAX_TRADES_PER_PAIR"
        );

        require(
            storageT.pendingOrderIdsCount(sender) <
                storageT.maxPendingMarketOrders(),
            "MAX_PENDING_ORDERS"
        );
        require(t.positionSizeWETH <= maxPosWETH, "ABOVE_MAX_POS");
        require(
            t.positionSizeWETH * t.leverage >=
                pairsStored.pairMinLevPosWETH(t.pairIndex),
            "BELOW_MIN_POS"
        );

        require(
            t.leverage > 0 &&
                t.leverage >= pairsStored.pairMinLeverage(t.pairIndex) &&
                t.leverage <= pairMaxLeverage(pairsStored, t.pairIndex),
            "LEVERAGE_INCORRECT"
        );

        // require(
        //     spreadReductionId == 0 ||
        //         storageT.nfts(spreadReductionId - 1).balanceOf(sender) > 0,
        //     "NO_CORRESPONDING_NFT_SPREAD_REDUCTION"
        // );

        require(
            t.tp == 0 || (t.buy ? t.tp > t.openPrice : t.tp < t.openPrice),
            "WRONG_TP"
        );
        require(
            t.sl == 0 || (t.buy ? t.sl < t.openPrice : t.sl > t.openPrice),
            "WRONG_SL"
        );

        (uint priceImpactP, ) = pairInfos.getTradePriceImpact(
            0,
            t.pairIndex,
            t.buy,
            t.positionSizeWETH * t.leverage
        );
        require(
            priceImpactP * t.leverage <= pairInfos.maxNegativePnlOnOpenP(),
            "PRICE_IMPACT_TOO_HIGH"
        );

        storageT.transferWETH(sender, address(storageT), t.positionSizeWETH);

        if (orderType != NftRewardsInterfaceV6_3_1.OpenLimitOrderType.LEGACY) {
            // uint index = storageT.firstEmptyOpenLimitIndex(sender, t.pairIndex);
            // storageT.storeOpenLimitOrder(
            //     StorageInterface.OpenLimitOrder(
            //         sender,
            //         t.pairIndex,
            //         index,
            //         t.positionSizeWETH,
            //         spreadReductionId > 0
            //             ? storageT.spreadReductionsP(spreadReductionId - 1)
            //             : 0,
            //         t.buy,
            //         t.leverage,
            //         t.tp,
            //         t.sl,
            //         t.openPrice,
            //         t.openPrice,
            //         ChainUtils.getBlockNumber(),
            //         0
            //     )
            // );
            // nftRewards.setOpenLimitOrderType(
            //     sender,
            //     t.pairIndex,
            //     index,
            //     orderType
            // );
            // address c = storageT.callbacks();
            // c.setTradeLastUpdated(
            //     sender,
            //     t.pairIndex,
            //     index,
            //     TradingCallbacksInterface.TradeType.LIMIT,
            //     ChainUtils.getBlockNumber()
            // );
            // c.setTradeData(
            //     sender,
            //     t.pairIndex,
            //     index,
            //     TradingCallbacksInterface.TradeType.LIMIT,
            //     slippageP
            // );
            // emit OpenLimitPlaced(sender, t.pairIndex, index);
        } else {
            uint orderId = aggregator.getPrice(
                t.pairIndex,
                AggregatorInterfaceV1_4.OrderType.MARKET_OPEN,
                t.positionSizeWETH * t.leverage,
                ChainUtils.getBlockNumber()
            );

            // storageT.storePendingMarketOrder(
            //     StorageInterface.PendingMarketOrder(
            //         StorageInterface.Trade(
            //             sender,
            //             t.pairIndex,
            //             0,
            //             0,
            //             t.positionSizeWETH,
            //             0,
            //             t.buy,
            //             t.leverage,
            //             t.tp,
            //             t.sl
            //         ),
            //         0,
            //         t.openPrice,
            //         slippageP,
            //         0,
            //         0
            //     ),
            //     orderId,
            //     true
            // );

            (storageT.priceAggregator()).marketOrderfulfill(
                orderId,
                StorageInterface.PendingMarketOrder(
                    StorageInterface.Trade(
                        sender,
                        t.pairIndex,
                        0,
                        0,
                        t.positionSizeWETH,
                        0,
                        t.buy,
                        t.leverage,
                        t.tp,
                        t.sl
                    ),
                    0,
                    t.openPrice,
                    slippageP,
                    0,
                    0
                )
            );

            emit MarketOrderInitiated(orderId, sender, t.pairIndex, true);
        }

        // referrals.registerPotentialReferrer(sender, referrer);
    }

    // Close trade (MARKET)
    function closeTradeMarket(
        uint pairIndex,
        uint index
    ) external notContract notDone {
        address sender = _msgSender();
        StorageInterface.Trade memory t = storageT.getOpenTrades(
            sender,
            pairIndex,
            index
        );

        StorageInterface.TradeInfo memory i = storageT.getOpenTradesInfo(
            sender,
            pairIndex,
            index
        );

        require(
            storageT.pendingOrderIdsCount(sender) <
                storageT.maxPendingMarketOrders(),
            "MAX_PENDING_ORDERS"
        );
        require(!i.beingMarketClosed, "ALREADY_BEING_CLOSED");
        require(t.leverage > 0, "NO_TRADE");

        uint orderId = AggregatorInterfaceV1_4(
            address(storageT.priceAggregator())
        ).getPrice(
                pairIndex,
                AggregatorInterfaceV1_4.OrderType.MARKET_CLOSE,
                (t.initialPosToken * i.tokenPriceWETH * t.leverage) / PRECISION,
                ChainUtils.getBlockNumber()
            );

        // storageT.storePendingMarketOrder(
        //     StorageInterface.PendingMarketOrder(
        //         StorageInterface.Trade(
        //             sender,
        //             pairIndex,
        //             index,
        //             0,
        //             0,
        //             0,
        //             false,
        //             0,
        //             0,
        //             0
        //         ),
        //         0,
        //         0,
        //         0,
        //         0,
        //         0
        //     ),
        //     orderId,
        //     false
        // );

        (storageT.priceAggregator()).marketOrderfulfill(
            orderId,
            StorageInterface.PendingMarketOrder(
                StorageInterface.Trade(
                    sender,
                    pairIndex,
                    index,
                    0,
                    0,
                    0,
                    false,
                    0,
                    0,
                    0
                ),
                0,
                0,
                0,
                0,
                0
            )
        );

        emit MarketOrderInitiated(orderId, sender, pairIndex, false);
    }

    // Manage limit order (OPEN)
    // function updateOpenLimitOrder(
    //     uint pairIndex,
    //     uint index,
    //     uint price, // PRECISION
    //     uint tp,
    //     uint sl,
    //     uint maxSlippageP
    // ) external notContract notDone {
    //     require(price > 0, "PRICE_ZERO");

    //     address sender = _msgSender();
    //     require(
    //         storageT.hasOpenLimitOrder(sender, pairIndex, index),
    //         "NO_LIMIT"
    //     );

    //     StorageInterface.OpenLimitOrder memory o = storageT.getOpenLimitOrder(
    //         sender,
    //         pairIndex,
    //         index
    //     );

    //     require(tp == 0 || (o.buy ? tp > price : tp < price), "WRONG_TP");
    //     require(sl == 0 || (o.buy ? sl < price : sl > price), "WRONG_SL");

    //     require(price * maxSlippageP < type(uint256).max, "OVERFLOW");

    //     checkNoPendingTrigger(
    //         sender,
    //         pairIndex,
    //         index,
    //         StorageInterface.LimitOrder.OPEN
    //     );

    //     o.minPrice = price;
    //     o.maxPrice = price;
    //     o.tp = tp;
    //     o.sl = sl;

    //     storageT.updateOpenLimitOrder(o);

    //     address c = storageT.callbacks();
    //     c.setTradeLastUpdated(
    //         sender,
    //         pairIndex,
    //         index,
    //         TradingCallbacksInterface.TradeType.LIMIT,
    //         ChainUtils.getBlockNumber()
    //     );
    //     c.setTradeData(
    //         sender,
    //         pairIndex,
    //         index,
    //         TradingCallbacksInterface.TradeType.LIMIT,
    //         maxSlippageP
    //     );

    //     emit OpenLimitUpdated(
    //         sender,
    //         pairIndex,
    //         index,
    //         price,
    //         tp,
    //         sl,
    //         maxSlippageP
    //     );
    // }

    // function cancelOpenLimitOrder(
    //     uint pairIndex,
    //     uint index
    // ) external notContract notDone {
    //     address sender = _msgSender();
    //     require(
    //         storageT.hasOpenLimitOrder(sender, pairIndex, index),
    //         "NO_LIMIT"
    //     );

    //     StorageInterface.OpenLimitOrder memory o = storageT.getOpenLimitOrder(
    //         sender,
    //         pairIndex,
    //         index
    //     );

    //     checkNoPendingTrigger(
    //         sender,
    //         pairIndex,
    //         index,
    //         StorageInterface.LimitOrder.OPEN
    //     );

    //     storageT.unregisterOpenLimitOrder(sender, pairIndex, index);
    //     storageT.transferWETH(address(storageT), sender, o.positionSize);

    //     emit OpenLimitCanceled(sender, pairIndex, index);
    // }

    // Manage limit order (TP/SL)
    function updateTp(
        uint pairIndex,
        uint index,
        uint newTp
    ) external notContract notDone {
        address sender = _msgSender();

        // checkNoPendingTrigger(
        //     sender,
        //     pairIndex,
        //     index,
        //     StorageInterface.LimitOrder.TP
        // );
        StorageInterface.Trade memory t = storageT.getOpenTrades(
            sender,
            pairIndex,
            index
        );
        require(t.leverage > 0, "NO_TRADE");

        storageT.updateTp(sender, pairIndex, index, newTp);
        address(storageT.callbacks()).setTpLastUpdated(
            sender,
            pairIndex,
            index,
            TradingCallbacksInterface.TradeType.MARKET,
            ChainUtils.getBlockNumber()
        );

        emit TpUpdated(sender, pairIndex, index, newTp);
    }

    function updateSl(
        uint pairIndex,
        uint index,
        uint newSl
    ) external notContract notDone {
        address sender = _msgSender();

        // checkNoPendingTrigger(
        //     sender,
        //     pairIndex,
        //     index,
        //     StorageInterface.LimitOrder.SL
        // );

        StorageInterface.Trade memory t = storageT.getOpenTrades(
            sender,
            pairIndex,
            index
        );
        require(t.leverage > 0, "NO_TRADE");

        uint maxSlDist = (t.openPrice * MAX_SL_P) / 100 / t.leverage;

        require(
            newSl == 0 ||
                (
                    t.buy
                        ? newSl >= t.openPrice - maxSlDist
                        : newSl <= t.openPrice + maxSlDist
                ),
            "SL_TOO_BIG"
        );

        storageT.updateSl(sender, pairIndex, index, newSl);
        address(storageT.callbacks()).setSlLastUpdated(
            sender,
            pairIndex,
            index,
            TradingCallbacksInterface.TradeType.MARKET,
            ChainUtils.getBlockNumber()
        );

        emit SlUpdated(sender, pairIndex, index, newSl);
    }

    function executeLiquidations(
        uint[100] memory _orderTypes,
        address[100] memory traders,
        uint[100] memory pairIndexs,
        uint[100] memory indexs,
        uint256 index
    ) public notDone {
        for (uint i; i < index; i++) {
            executeLiquidation(
                _orderTypes[i],
                traders[i],
                pairIndexs[i],
                indexs[i],
                1,
                1
            );
        }
    }

    // Execute limit order
    function executeLiquidation(
        uint _orderType,
        address trader,
        uint pairIndex,
        uint index,
        uint nftId,
        uint nftType
    ) public notDone {
        // (
        //     uint _orderType,
        //     address trader,
        //     uint pairIndex,
        //     uint index,
        //     uint nftId,
        //     uint nftType
        // ) = packed.unpackExecuteNftOrder();
        StorageInterface.LimitOrder orderType = StorageInterface.LimitOrder(
            _orderType
        );
        address sender = _msgSender();

        // require(nftType >= 1 && nftType <= 5, "WRONG_NFT_TYPE");
        // require(storageT.nfts(nftType - 1).ownerOf(nftId) == sender, "NO_NFT");

        // require(
        //     ChainUtils.getBlockNumber() >=
        //         storageT.nftLastSuccess(nftId) + storageT.nftSuccessTimelock(),
        //     "SUCCESS_TIMELOCK"
        // );

        bool isOpenLimit = orderType == StorageInterface.LimitOrder.OPEN;
        TradingCallbacksInterface.TradeType tradeType = isOpenLimit
            ? TradingCallbacksInterface.TradeType.LIMIT
            : TradingCallbacksInterface.TradeType.MARKET;

        // require(
        //     canExecute(
        //         orderType,
        //         TradingCallbacksInterface.SimplifiedTradeId(
        //             trader,
        //             pairIndex,
        //             index,
        //             tradeType
        //         )
        //     ),
        //     "IN_TIMEOUT"
        // );

        // handleBotInUse(sender, nftId, trader, pairIndex, index);

        StorageInterface.Trade memory t;

        if (isOpenLimit) {
            revert("Open Limit orders not supported yet");
            // require(
            //     storageT.hasOpenLimitOrder(trader, pairIndex, index),
            //     "NO_LIMIT"
            // );
        } else {
            t = storageT.getOpenTrades(trader, pairIndex, index);

            require(t.leverage > 0, "NO_TRADE");

            if (orderType == StorageInterface.LimitOrder.LIQ) {
                uint liqPrice = borrowingFees.getTradeLiquidationPrice(
                    BorrowingFeesInterface.LiqPriceInput(
                        t.trader,
                        t.pairIndex,
                        t.index,
                        t.openPrice,
                        t.buy,
                        t.positionSizeWETH,
                        t.leverage
                    )
                );

                require(
                    t.sl == 0 || (t.buy ? liqPrice > t.sl : liqPrice < t.sl),
                    "HAS_SL"
                );
            } else if (orderType == StorageInterface.LimitOrder.PAR_LIQ) {
                uint parLiqPrice = borrowingFees
                    .getTradePartialLiquidationPrice(
                        BorrowingFeesInterface.LiqPriceInput(
                            t.trader,
                            t.pairIndex,
                            t.index,
                            t.openPrice,
                            t.buy,
                            t.positionSizeWETH,
                            t.leverage
                        )
                    );

                require(
                    t.sl == 0 ||
                        (t.buy ? parLiqPrice > t.sl : parLiqPrice < t.sl),
                    "HAS_SL"
                );
                int256 pnl = callbacks.getTradePnl(
                    t.trader,
                    t.pairIndex,
                    t.index
                );
                int256 position = int(t.positionSizeWETH) + pnl;
                require(
                    position * int256(t.leverage) >= minLeveragedPosWETH,
                    "position too small for partial liquidation"
                );
            } else {
                require(
                    orderType != StorageInterface.LimitOrder.SL || t.sl > 0,
                    "NO_SL"
                );
                require(
                    orderType != StorageInterface.LimitOrder.TP || t.tp > 0,
                    "NO_TP"
                );
            }
        }

        // NftRewardsInterfaceV6_3_1.TriggeredLimitId
        //     memory triggeredLimitId = NftRewardsInterfaceV6_3_1
        //         .TriggeredLimitId(trader, pairIndex, index, orderType);

        if (
            true
            // !nftRewards.triggered(triggeredLimitId) ||
            // nftRewards.timedOut(triggeredLimitId)
        ) {
            uint leveragedPosWETH;

            if (isOpenLimit) {
                // StorageInterface.OpenLimitOrder memory l = storageT
                //     .getOpenLimitOrder(trader, pairIndex, index);
                // leveragedPosWETH = l.positionSize * l.leverage;
                // (uint priceImpactP, ) = pairInfos.getTradePriceImpact(
                //     0,
                //     l.pairIndex,
                //     l.buy,
                //     leveragedPosWETH
                // );
                // require(
                //     priceImpactP * l.leverage <=
                //         pairInfos.maxNegativePnlOnOpenP(),
                //     "PRICE_IMPACT_TOO_HIGH"
                // );
            } else {
                leveragedPosWETH = t.positionSizeWETH * t.leverage;
            }

            // storageT.transferLinkToAggregator(
            //     sender,
            //     pairIndex,
            //     leveragedPosWETH
            // );

            (uint orderId /*uint linkFee*/, ) = getPriceNftOrder(
                isOpenLimit,
                trader,
                pairIndex,
                index,
                tradeType,
                orderType,
                leveragedPosWETH
            );

            StorageInterface.PendingNftOrder memory pendingNftOrder;
            pendingNftOrder.nftHolder = sender;
            pendingNftOrder.nftId = nftId;
            pendingNftOrder.trader = trader;
            pendingNftOrder.pairIndex = pairIndex;
            pendingNftOrder.index = index;
            pendingNftOrder.orderType = orderType;
            storageT.storePendingNftOrder(pendingNftOrder, orderId);

            (storageT.priceAggregator()).nftOrderfulfill(
                orderId,
                pendingNftOrder
            );
            emit NftOrderInitiated(orderId, sender, trader, pairIndex);
        } else {
            // nftRewards.storeTriggerSameBlock(triggeredLimitId, sender);

            emit NftOrderSameBlock(sender, trader, pairIndex);
        }
    }

    // Market timeout
    // function openTradeMarketTimeout(uint _order) external notContract notDone {
    //     address sender = _msgSender();

    //     StorageInterface.PendingMarketOrder memory o = storageT
    //         .reqID_pendingMarketOrder(_order);
    //     StorageInterface.Trade memory t = o.trade;

    //     require(
    //         o.block > 0 && ChainUtils.getBlockNumber() >= o.block + marketOrdersTimeout,
    //         "WAIT_TIMEOUT"
    //     );
    //     require(t.trader == sender, "NOT_YOUR_ORDER");
    //     require(t.leverage > 0, "WRONG_MARKET_ORDER_TYPE");

    //     storageT.unregisterPendingMarketOrder(_order, true);
    //     storageT.transferWETH(address(storageT), sender, t.positionSizeWETH);

    //     emit ChainlinkCallbackTimeout(_order, o);
    // }

    // function closeTradeMarketTimeout(uint _order) external notContract notDone {
    //     address sender = _msgSender();

    //     StorageInterface.PendingMarketOrder memory o = storageT
    //         .reqID_pendingMarketOrder(_order);
    //     StorageInterface.Trade memory t = o.trade;

    //     require(
    //         o.block > 0 && ChainUtils.getBlockNumber() >= o.block + marketOrdersTimeout,
    //         "WAIT_TIMEOUT"
    //     );
    //     require(t.trader == sender, "NOT_YOUR_ORDER");
    //     require(t.leverage == 0, "WRONG_MARKET_ORDER_TYPE");

    //     storageT.unregisterPendingMarketOrder(_order, false);

    //     (bool success, ) = address(this).delegatecall(
    //         abi.encodeWithSignature(
    //             "closeTradeMarket(uint256,uint256)",
    //             t.pairIndex,
    //             t.index
    //         )
    //     );

    //     if (!success) {
    //         emit CouldNotCloseTrade(sender, t.pairIndex, t.index);
    //     }

    //     emit ChainlinkCallbackTimeout(_order, o);
    // }

    // //Helpers
    // function checkNoPendingTrigger(
    //     address trader,
    //     uint pairIndex,
    //     uint index,
    //     StorageInterface.LimitOrder orderType
    // ) private view {
    //     NftRewardsInterfaceV6_3_1.TriggeredLimitId
    //         memory triggeredLimitId = NftRewardsInterfaceV6_3_1
    //             .TriggeredLimitId(trader, pairIndex, index, orderType);
    //     require(
    //         !nftRewards.triggered(triggeredLimitId) ||
    //             nftRewards.timedOut(triggeredLimitId),
    //         "PENDING_TRIGGER"
    //     );
    // }

    // function canExecute(
    //     StorageInterface.LimitOrder orderType,
    //     TradingCallbacksInterface.SimplifiedTradeId memory id
    // ) private view returns (bool) {
    //     if (orderType == StorageInterface.LimitOrder.LIQ) return true;

    //     uint b = ChainUtils.getBlockNumber();
    //     address cb = storageT.callbacks();

    //     if (orderType == StorageInterface.LimitOrder.TP)
    //         return !cb.isTpInTimeout(id, b);
    //     if (orderType == StorageInterface.LimitOrder.SL)
    //         return !cb.isSlInTimeout(id, b);

    //     return !cb.isLimitInTimeout(id, b);
    // }

    function pairMaxLeverage(
        PairsStorageInterfaceV6 pairsStored,
        uint pairIndex
    ) private view returns (uint) {
        uint max = TradingCallbacksInterface(address(storageT.callbacks()))
            .pairMaxLeverage(pairIndex);
        return max > 0 ? max : pairsStored.pairMaxLeverage(pairIndex);
    }

    // function handleBotInUse(
    //     address sender,
    //     uint nftId,
    //     address trader,
    //     uint pairIndex,
    //     uint index
    // ) private {
    //     (bytes32 nftHash, bytes32 botHash) = nftRewards.getNftBotHashes(
    //         ChainUtils.getBlockNumber(),
    //         sender,
    //         nftId,
    //         trader,
    //         pairIndex,
    //         index
    //     );
    //     require(!nftRewards.nftBotInUse(nftHash, botHash), "BOT_IN_USE");

    //     nftRewards.setNftBotInUse(nftHash, botHash);
    // }

    function getPriceNftOrder(
        bool isOpenLimit,
        address trader,
        uint pairIndex,
        uint index,
        TradingCallbacksInterface.TradeType tradeType,
        StorageInterface.LimitOrder orderType,
        uint leveragedPosWETH
    ) private returns (uint orderId, uint linkFee) {
        TradingCallbacksInterface.LastUpdated
            memory lastUpdated = TradingCallbacksInterface(
                address(storageT.callbacks())
            ).tradeLastUpdated(trader, pairIndex, index, tradeType);

        AggregatorInterfaceV1_4 aggregator = AggregatorInterfaceV1_4(
            address(storageT.priceAggregator())
        );

        orderId = aggregator.getPrice(
            pairIndex,
            isOpenLimit
                ? AggregatorInterfaceV1_4.OrderType.LIMIT_OPEN
                : AggregatorInterfaceV1_4.OrderType.LIMIT_CLOSE,
            leveragedPosWETH,
            isOpenLimit
                ? lastUpdated.limit
                : orderType == StorageInterface.LimitOrder.SL
                ? lastUpdated.sl
                : orderType == StorageInterface.LimitOrder.TP
                ? lastUpdated.tp
                : lastUpdated.created
        );

        // linkFee = aggregator.linkFee(pairIndex, leveragedPosWETH);
    }

    function isTradeLiquidatable(
        address trader,
        uint pairIndex,
        uint index
    ) external view returns (bool) {
        StorageInterface.Trade memory t = storageT.getOpenTrades(
            trader,
            pairIndex,
            index
        );

        (bool liquidatable, bool noSL) = isTradeLiquidatablePure(t);

        require(noSL, "HAS_SL");

        return liquidatable;
    }

    function isTradeLiquidatablePure(
        StorageInterface.Trade memory t
    ) public view returns (bool, bool) {
        if (t.leverage == 0) return (false, false);
        uint liqPrice = borrowingFees.getTradeLiquidationPrice(
            BorrowingFeesInterface.LiqPriceInput(
                t.trader,
                t.pairIndex,
                t.index,
                t.openPrice,
                t.buy,
                t.positionSizeWETH,
                t.leverage
            )
        );
        (uint256 price, uint256 lastUpdateTime) = (storageT.oracle()).getPrice(
            t.pairIndex
        );
        bool noSL = t.sl == 0 || (t.buy ? liqPrice > t.sl : liqPrice < t.sl);

        bool liquidatable = t.buy ? price <= liqPrice : price >= liqPrice;

        return (liquidatable, noSL);
    }

    function isTradeParLiquidatable(
        address trader,
        uint pairIndex,
        uint index
    ) external view returns (bool) {
        StorageInterface.Trade memory t = storageT.getOpenTrades(
            trader,
            pairIndex,
            index
        );

        (uint256 price, uint256 lastUpdateTime) = (storageT.oracle()).getPrice(
            pairIndex
        );

        (bool parLiquidatable, bool noSL) = isTradeParLiquidatablePure(t);

        require(noSL, "HAS_SL");

        return parLiquidatable;
    }

    function isTradeParLiquidatablePure(
        StorageInterface.Trade memory t
    ) public view returns (bool, bool) {
        if (t.leverage == 0) return (false, false);

        uint parLiqPrice = borrowingFees.getTradePartialLiquidationPrice(
            BorrowingFeesInterface.LiqPriceInput(
                t.trader,
                t.pairIndex,
                t.index,
                t.openPrice,
                t.buy,
                t.positionSizeWETH,
                t.leverage
            )
        );
        int256 pnl = callbacks.getTradePnl(t.trader, t.pairIndex, t.index);
        int256 position = int(t.positionSizeWETH) + pnl;
        bool noSL = t.sl == 0 ||
            (t.buy ? parLiqPrice > t.sl : parLiqPrice < t.sl);
        if (position * int256(t.leverage) < minLeveragedPosWETH)
            return (false, noSL);
        (uint256 price, uint256 lastUpdateTime) = (storageT.oracle()).getPrice(
            t.pairIndex
        );

        bool parLiquidatable = t.buy
            ? price <= parLiqPrice
            : price >= parLiqPrice;

        return (parLiquidatable, noSL);
    }
}
