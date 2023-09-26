// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/StorageInterface.sol";
import "./interfaces/NFTRewardInterfaceV6_3.sol";
import "./interfaces/PairInfosInterface.sol";
import "./interfaces/ReferralsInterface.sol";
import "./interfaces/StakingInterface.sol";
import "./libraries/ChainUtils.sol";
import "./interfaces/BorrowingFeesInterface.sol";

contract TradingCallbacks is Initializable {
    // Contracts (constant)
    StorageInterface public storageT;
    NftRewardsInterfaceV6_3_1 public nftRewards;
    PairInfosInterface public pairInfos;
    ReferralsInterface public referrals;
    StakingInterface public staking;

    // Params (constant)
    uint constant PRECISION = 1e10; // 10 decimals

    uint constant MAX_SL_P = 75; // -75% PNL
    uint constant MAX_GAIN_P = 900; // 900% PnL (10x)
    uint constant MAX_EXECUTE_TIMEOUT = 5; // 5 blocks

    // Params (adjustable)
    uint public WETHVaultFeeP; // % of closing fee going to WETH vault (eg. 40)
    uint public lpFeeP; // % of closing fee going to GNS/WETH LPs (eg. 20)
    uint public sssFeeP; // % of closing fee going to GNS staking (eg. 40)

    // State
    bool public isPaused; // Prevent opening new trades
    bool public isDone; // Prevent any interaction with the contract
    uint public canExecuteTimeout; // How long an update to TP/SL/Limit has to wait before it is executable

    // Last Updated State
    mapping(address => mapping(uint => mapping(uint => mapping(TradeType => LastUpdated))))
        public tradeLastUpdated; // Block numbers for last updated

    // v6.3.2 Storage/State
    BorrowingFeesInterface public borrowingFees;

    mapping(uint => uint) public pairMaxLeverage;

    // v6.4 Storage
    mapping(address => mapping(uint => mapping(uint => mapping(TradeType => TradeData))))
        public tradeData; // More storage for trades / limit orders

    // Custom data types
    struct AggregatorAnswer {
        uint orderId;
        uint price;
        uint spreadP;
        uint open;
        uint high;
        uint low;
    }

    // Useful to avoid stack too deep errors
    struct Values {
        uint posWETH;
        uint levPosWETH;
        uint tokenPriceWETH;
        int profitP;
        uint price;
        uint liqPrice;
        uint WETHSentToTrader;
        uint reward1;
        uint reward2;
        uint reward3;
        bool exactExecution;
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

    struct OpenTradePrepInput {
        uint executionPrice;
        uint wantedPrice;
        uint marketPrice;
        uint spreadP;
        uint spreadReductionP;
        bool buy;
        uint pairIndex;
        uint positionSize;
        uint leverage;
        uint maxSlippageP;
        uint tp;
        uint sl;
    }

    enum TradeType {
        MARKET,
        LIMIT
    }

    enum CancelReason {
        NONE,
        PAUSED,
        MARKET_CLOSED,
        SLIPPAGE,
        TP_REACHED,
        SL_REACHED,
        EXPOSURE_LIMITS,
        PRICE_IMPACT,
        MAX_LEVERAGE,
        NO_TRADE,
        WRONG_TRADE,
        NOT_HIT
    }

    // Events
    event MarketExecuted(
        uint indexed orderId,
        StorageInterface.Trade t,
        bool open,
        uint price,
        uint priceImpactP,
        uint positionSizeWETH,
        int percentProfit, // before fees
        uint WETHSentToTrader
    );

    event LimitExecuted(
        uint indexed orderId,
        uint limitIndex,
        StorageInterface.Trade t,
        address indexed nftHolder,
        StorageInterface.LimitOrder orderType,
        uint price,
        uint priceImpactP,
        uint positionSizeWETH,
        int percentProfit,
        uint WETHSentToTrader,
        bool exactExecution
    );

    event MarketOpenCanceled(
        uint indexed orderId,
        address indexed trader,
        uint indexed pairIndex,
        CancelReason cancelReason
    );
    event MarketCloseCanceled(
        uint indexed orderId,
        address indexed trader,
        uint indexed pairIndex,
        uint index,
        CancelReason cancelReason
    );
    event NftOrderCanceled(
        uint indexed orderId,
        address indexed nftHolder,
        StorageInterface.LimitOrder orderType,
        CancelReason cancelReason
    );

    event ClosingFeeSharesPUpdated(
        uint WETHVaultFeeP,
        uint lpFeeP,
        uint sssFeeP
    );
    event CanExecuteTimeoutUpdated(uint newValue);

    event Pause(bool paused);
    event Done(bool done);

    event DevGovFeeCharged(address indexed trader, uint valueWETH);
    event ReferralFeeCharged(address indexed trader, uint valueWETH);
    event NftBotFeeCharged(address indexed trader, uint valueWETH);
    event SssFeeCharged(address indexed trader, uint valueWETH);
    event WETHVaultFeeCharged(address indexed trader, uint valueWETH);
    event BorrowingFeeCharged(
        address indexed trader,
        uint tradeValueWETH,
        uint feeValueWETH
    );
    event PairMaxLeverageUpdated(uint indexed pairIndex, uint maxLeverage);

    // Custom errors (save gas)
    error WrongParams();
    error Forbidden();

    function initialize(
        StorageInterface _storageT,
        NftRewardsInterfaceV6_3_1 _nftRewards,
        PairInfosInterface _pairInfos,
        ReferralsInterface _referrals,
        StakingInterface _staking,
        BorrowingFeesInterface _borrowingFees,
        address vaultToApprove,
        uint _WETHVaultFeeP,
        uint _lpFeeP,
        uint _sssFeeP,
        uint _canExecuteTimeout
    ) external initializer {
        if (
            address(_storageT) == address(0) ||
            address(_nftRewards) == address(0) ||
            address(_pairInfos) == address(0) ||
            address(_referrals) == address(0) ||
            address(_staking) == address(0) ||
            vaultToApprove == address(0) ||
            _WETHVaultFeeP + _lpFeeP + _sssFeeP != 100 ||
            _canExecuteTimeout > MAX_EXECUTE_TIMEOUT
        ) {
            revert WrongParams();
        }

        storageT = _storageT;
        nftRewards = _nftRewards;
        pairInfos = _pairInfos;
        referrals = _referrals;
        staking = _staking;
        borrowingFees = _borrowingFees;

        WETHVaultFeeP = _WETHVaultFeeP;
        lpFeeP = _lpFeeP;
        sssFeeP = _sssFeeP;

        canExecuteTimeout = _canExecuteTimeout;
        TokenInterface t = storageT.WETH();
        t.approve(address(staking), type(uint256).max);
        t.approve(vaultToApprove, type(uint256).max);
    }

    // function initializeV2(
    //     BorrowingFeesInterface _borrowingFees
    // ) external reinitializer(2) {
    //     if (address(_borrowingFees) == address(0)) {
    //         revert WrongParams();
    //     }
    //     borrowingFees = _borrowingFees;
    // }

    // Modifiers
    modifier onlyGov() {
        isGov();
        _;
    }
    modifier onlyPriceAggregator() {
        isPriceAggregator();
        _;
    }
    modifier notDone() {
        isNotDone();
        _;
    }
    modifier onlyTrading() {
        isTrading();
        _;
    }
    modifier onlyManager() {
        isManager();
        _;
    }

    // Saving code size by calling these functions inside modifiers
    function isGov() private view {
        if (msg.sender != storageT.gov()) {
            revert Forbidden();
        }
    }

    function isPriceAggregator() private view {
        if (msg.sender != address(storageT.priceAggregator())) {
            revert Forbidden();
        }
    }

    function isNotDone() private view {
        if (isDone) {
            revert Forbidden();
        }
    }

    function isTrading() private view {
        if (msg.sender != storageT.trading()) {
            revert Forbidden();
        }
    }

    function isManager() private view {
        if (msg.sender != pairInfos.manager()) {
            revert Forbidden();
        }
    }

    // Manage params
    function setPairMaxLeverage(uint pairIndex, uint maxLeverage) external {
        _setPairMaxLeverage(pairIndex, maxLeverage);
    }

    function setPairMaxLeverageArray(
        uint[] calldata indices,
        uint[] calldata values
    ) external onlyManager {
        uint len = indices.length;

        if (len != values.length) {
            revert WrongParams();
        }

        for (uint i; i < len; ) {
            _setPairMaxLeverage(indices[i], values[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _setPairMaxLeverage(uint pairIndex, uint maxLeverage) private {
        pairMaxLeverage[pairIndex] = maxLeverage;
        emit PairMaxLeverageUpdated(pairIndex, maxLeverage);
    }

    function setClosingFeeSharesP(
        uint _WETHVaultFeeP,
        uint _lpFeeP,
        uint _sssFeeP
    ) external onlyGov {
        if (_WETHVaultFeeP + _lpFeeP + _sssFeeP != 100) {
            revert WrongParams();
        }

        WETHVaultFeeP = _WETHVaultFeeP;
        lpFeeP = _lpFeeP;
        sssFeeP = _sssFeeP;

        emit ClosingFeeSharesPUpdated(_WETHVaultFeeP, _lpFeeP, _sssFeeP);
    }

    function setCanExecuteTimeout(uint _canExecuteTimeout) external onlyGov {
        if (_canExecuteTimeout > MAX_EXECUTE_TIMEOUT) {
            revert WrongParams();
        }
        canExecuteTimeout = _canExecuteTimeout;
        emit CanExecuteTimeoutUpdated(_canExecuteTimeout);
    }

    // Manage state
    function pause() external onlyGov {
        isPaused = !isPaused;

        emit Pause(isPaused);
    }

    function done() external onlyGov {
        isDone = !isDone;

        emit Done(isDone);
    }

    // Callbacks
    function openTradeMarketCallback(
        AggregatorAnswer memory a
    ) external onlyPriceAggregator notDone {
        StorageInterface.PendingMarketOrder memory o = getPendingMarketOrder(
            a.orderId
        );

        if (o.block == 0) {
            return;
        }

        StorageInterface.Trade memory t = o.trade;

        (
            uint priceImpactP,
            uint priceAfterImpact,
            CancelReason cancelReason
        ) = _openTradePrep(
                OpenTradePrepInput(
                    a.price,
                    o.wantedPrice,
                    a.price,
                    a.spreadP,
                    o.spreadReductionP,
                    t.buy,
                    t.pairIndex,
                    t.positionSizeWETH,
                    t.leverage,
                    o.slippageP,
                    t.tp,
                    t.sl
                )
            );

        t.openPrice = priceAfterImpact;

        if (cancelReason == CancelReason.NONE) {
            (StorageInterface.Trade memory finalTrade, ) = registerTrade(
                t,
                1500,
                0
            );

            emit MarketExecuted(
                a.orderId,
                finalTrade,
                true,
                finalTrade.openPrice,
                priceImpactP,
                (finalTrade.positionSizeWETH * finalTrade.leverage),
                0,
                0
            );
        } else {
            // uint devGovFeesWETH = storageT.handleDevGovFees(
            //     t.pairIndex,
            //     t.positionSizeWETH * t.leverage,
            //     true,
            //     true
            // );
            // transferFromStorageToAddress(
            //     t.trader,
            //     t.positionSizeWETH - devGovFeesWETH
            // );

            // emit DevGovFeeCharged(t.trader, devGovFeesWETH);
            emit MarketOpenCanceled(
                a.orderId,
                t.trader,
                t.pairIndex,
                cancelReason
            );
        }

        storageT.unregisterPendingMarketOrder(a.orderId, true);
    }

    function closeTradeMarketCallback(
        AggregatorAnswer memory a
    ) external onlyPriceAggregator notDone {
        StorageInterface.PendingMarketOrder memory o = getPendingMarketOrder(
            a.orderId
        );

        if (o.block == 0) {
            return;
        }

        StorageInterface.Trade memory t = getOpenTrade(
            o.trade.trader,
            o.trade.pairIndex,
            o.trade.index
        );

        CancelReason cancelReason = t.leverage == 0
            ? CancelReason.NO_TRADE
            : (a.price == 0 ? CancelReason.MARKET_CLOSED : CancelReason.NONE);

        if (cancelReason != CancelReason.NO_TRADE) {
            StorageInterface.TradeInfo memory i = getOpenTradeInfo(
                t.trader,
                t.pairIndex,
                t.index
            );
            AggregatorInterfaceV1_4 aggregator = storageT.priceAggregator();

            Values memory v;
            v.levPosWETH = (t.positionSizeWETH * t.leverage);
            // v.tokenPriceWETH = aggregator.tokenPriceWETH();

            if (cancelReason == CancelReason.NONE) {
                v.profitP = currentPercentProfit(
                    t.openPrice,
                    a.price,
                    t.buy,
                    t.leverage
                );
                v.posWETH = v.levPosWETH / t.leverage;

                v.WETHSentToTrader = unregisterTrade(
                    t,
                    true,
                    v.profitP,
                    v.posWETH,
                    i.openInterestWETH,
                    (v.levPosWETH *
                        aggregator.pairsStorage().pairCloseFeeP(t.pairIndex)) /
                        100 /
                        PRECISION,
                    (v.levPosWETH *
                        aggregator.pairsStorage().pairNftLimitOrderFeeP(
                            t.pairIndex
                        )) /
                        100 /
                        PRECISION
                );

                emit MarketExecuted(
                    a.orderId,
                    t,
                    false,
                    a.price,
                    0,
                    v.posWETH,
                    v.profitP,
                    v.WETHSentToTrader
                );
            } else {
                // Dev / gov rewards to pay for oracle cost
                // Charge in WETH if collateral in storage or token if collateral in vault
                // v.reward1 = t.positionSizeWETH > 0
                //     ? storageT.handleDevGovFees(
                //         t.pairIndex,
                //         v.levPosWETH,
                //         true,
                //         true
                //     )
                //     : (storageT.handleDevGovFees(
                //         t.pairIndex,
                //         (v.levPosWETH * PRECISION) / v.tokenPriceWETH,
                //         false,
                //         true
                //     ) * v.tokenPriceWETH) / PRECISION;

                // t.initialPosToken -= (v.reward1 * PRECISION) / i.tokenPriceWETH;
                // storageT.updateTrade(t);

                emit DevGovFeeCharged(t.trader, v.reward1);
            }
        }

        if (cancelReason != CancelReason.NONE) {
            emit MarketCloseCanceled(
                a.orderId,
                o.trade.trader,
                o.trade.pairIndex,
                o.trade.index,
                cancelReason
            );
        }

        storageT.unregisterPendingMarketOrder(a.orderId, false);
    }

    function executeNftOpenOrderCallback(
        AggregatorAnswer memory a
    ) external onlyPriceAggregator notDone {
        StorageInterface.PendingNftOrder memory n = storageT
            .reqID_pendingNftOrder(a.orderId);

        CancelReason cancelReason = !storageT.hasOpenLimitOrder(
            n.trader,
            n.pairIndex,
            n.index
        )
            ? CancelReason.NO_TRADE
            : CancelReason.NONE;

        if (cancelReason == CancelReason.NONE) {
            StorageInterface.OpenLimitOrder memory o = storageT
                .getOpenLimitOrder(n.trader, n.pairIndex, n.index);

            NftRewardsInterfaceV6_3_1.OpenLimitOrderType t = nftRewards
                .openLimitOrderTypes(n.trader, n.pairIndex, n.index);

            cancelReason = (a.high >= o.maxPrice && a.low <= o.maxPrice)
                ? CancelReason.NONE
                : CancelReason.NOT_HIT;

            // Note: o.minPrice always equals o.maxPrice so can use either
            (
                uint priceImpactP,
                uint priceAfterImpact,
                CancelReason _cancelReason
            ) = _openTradePrep(
                    OpenTradePrepInput(
                        cancelReason == CancelReason.NONE ? o.maxPrice : a.open,
                        o.maxPrice,
                        a.open,
                        a.spreadP,
                        o.spreadReductionP,
                        o.buy,
                        o.pairIndex,
                        o.positionSize,
                        o.leverage,
                        tradeData[o.trader][o.pairIndex][o.index][
                            TradeType.LIMIT
                        ].maxSlippageP,
                        o.tp,
                        o.sl
                    )
                );

            bool exactExecution = cancelReason == CancelReason.NONE;

            cancelReason = !exactExecution &&
                (
                    o.maxPrice == 0 ||
                        t ==
                        NftRewardsInterfaceV6_3_1.OpenLimitOrderType.MOMENTUM
                        ? (o.buy ? a.open < o.maxPrice : a.open > o.maxPrice)
                        : (o.buy ? a.open > o.maxPrice : a.open < o.maxPrice)
                )
                ? CancelReason.NOT_HIT
                : _cancelReason;

            if (cancelReason == CancelReason.NONE) {
                (
                    StorageInterface.Trade memory finalTrade,
                    uint tokenPriceWETH
                ) = registerTrade(
                        StorageInterface.Trade(
                            o.trader,
                            o.pairIndex,
                            0,
                            0,
                            o.positionSize,
                            priceAfterImpact,
                            o.buy,
                            o.leverage,
                            o.tp,
                            o.sl
                        ),
                        n.nftId,
                        n.index
                    );

                storageT.unregisterOpenLimitOrder(
                    o.trader,
                    o.pairIndex,
                    o.index
                );

                emit LimitExecuted(
                    a.orderId,
                    n.index,
                    finalTrade,
                    n.nftHolder,
                    StorageInterface.LimitOrder.OPEN,
                    finalTrade.openPrice,
                    priceImpactP,
                    (finalTrade.initialPosToken * tokenPriceWETH) / PRECISION,
                    0,
                    0,
                    exactExecution
                );
            }
        }

        if (cancelReason != CancelReason.NONE) {
            emit NftOrderCanceled(
                a.orderId,
                n.nftHolder,
                StorageInterface.LimitOrder.OPEN,
                cancelReason
            );
        }

        nftRewards.unregisterTrigger(
            NftRewardsInterfaceV6_3_1.TriggeredLimitId(
                n.trader,
                n.pairIndex,
                n.index,
                n.orderType
            )
        );

        storageT.unregisterPendingNftOrder(a.orderId);
    }

    function executeNftCloseOrderCallback(
        AggregatorAnswer memory a
    ) external onlyPriceAggregator notDone {
        StorageInterface.PendingNftOrder memory o = storageT
            .reqID_pendingNftOrder(a.orderId);
        NftRewardsInterfaceV6_3_1.TriggeredLimitId
            memory triggeredLimitId = NftRewardsInterfaceV6_3_1
                .TriggeredLimitId(o.trader, o.pairIndex, o.index, o.orderType);
        StorageInterface.Trade memory t = getOpenTrade(
            o.trader,
            o.pairIndex,
            o.index
        );

        AggregatorInterfaceV1_4 aggregator = storageT.priceAggregator();

        CancelReason cancelReason = a.open == 0
            ? CancelReason.MARKET_CLOSED
            : (t.leverage == 0 ? CancelReason.NO_TRADE : CancelReason.NONE);

        if (cancelReason == CancelReason.NONE) {
            StorageInterface.TradeInfo memory i = getOpenTradeInfo(
                t.trader,
                t.pairIndex,
                t.index
            );

            PairsStorageInterfaceV6 pairsStored = aggregator.pairsStorage();

            Values memory v;
            v.levPosWETH =
                (t.initialPosToken * i.tokenPriceWETH * t.leverage) /
                PRECISION;
            v.posWETH = v.levPosWETH / t.leverage;

            if (o.orderType == StorageInterface.LimitOrder.LIQ) {
                v.liqPrice = borrowingFees.getTradeLiquidationPrice(
                    BorrowingFeesInterface.LiqPriceInput(
                        t.trader,
                        t.pairIndex,
                        t.index,
                        t.openPrice,
                        t.buy,
                        v.posWETH,
                        t.leverage
                    )
                );
            }

            v.price = o.orderType == StorageInterface.LimitOrder.TP
                ? t.tp
                : (
                    o.orderType == StorageInterface.LimitOrder.SL
                        ? t.sl
                        : v.liqPrice
                );

            v.exactExecution =
                v.price > 0 &&
                a.low <= v.price &&
                a.high >= v.price;

            if (v.exactExecution) {
                v.reward1 = o.orderType == StorageInterface.LimitOrder.LIQ
                    ? (v.posWETH * 5) / 100
                    : (v.levPosWETH *
                        pairsStored.pairNftLimitOrderFeeP(t.pairIndex)) /
                        100 /
                        PRECISION;
            } else {
                v.price = a.open;

                v.reward1 = o.orderType == StorageInterface.LimitOrder.LIQ
                    ? (
                        (t.buy ? a.open <= v.liqPrice : a.open >= v.liqPrice)
                            ? (v.posWETH * 5) / 100
                            : 0
                    )
                    : (
                        ((o.orderType == StorageInterface.LimitOrder.TP &&
                            t.tp > 0 &&
                            (t.buy ? a.open >= t.tp : a.open <= t.tp)) ||
                            (o.orderType == StorageInterface.LimitOrder.SL &&
                                t.sl > 0 &&
                                (t.buy ? a.open <= t.sl : a.open >= t.sl)))
                            ? (v.levPosWETH *
                                pairsStored.pairNftLimitOrderFeeP(
                                    t.pairIndex
                                )) /
                                100 /
                                PRECISION
                            : 0
                    );
            }

            cancelReason = v.reward1 == 0
                ? CancelReason.NOT_HIT
                : CancelReason.NONE;

            // If can be triggered
            if (cancelReason == CancelReason.NONE) {
                v.profitP = currentPercentProfit(
                    t.openPrice,
                    v.price,
                    t.buy,
                    t.leverage
                );
                v.tokenPriceWETH = aggregator.tokenPriceWETH();

                v.WETHSentToTrader = unregisterTrade(
                    t,
                    false,
                    v.profitP,
                    v.posWETH,
                    i.openInterestWETH,
                    o.orderType == StorageInterface.LimitOrder.LIQ
                        ? v.reward1
                        : (v.levPosWETH *
                            pairsStored.pairCloseFeeP(t.pairIndex)) /
                            100 /
                            PRECISION,
                    v.reward1
                );

                // Convert NFT bot fee from WETH to token value
                v.reward2 = (v.reward1 * PRECISION) / v.tokenPriceWETH;

                nftRewards.distributeNftReward(
                    triggeredLimitId,
                    v.reward2,
                    v.tokenPriceWETH
                );

                storageT.increaseNftRewards(o.nftId, v.reward2);

                emit NftBotFeeCharged(t.trader, v.reward1);

                emit LimitExecuted(
                    a.orderId,
                    o.index,
                    t,
                    o.nftHolder,
                    o.orderType,
                    v.price,
                    0,
                    v.posWETH,
                    v.profitP,
                    v.WETHSentToTrader,
                    v.exactExecution
                );
            }
        }

        if (cancelReason != CancelReason.NONE) {
            emit NftOrderCanceled(
                a.orderId,
                o.nftHolder,
                o.orderType,
                cancelReason
            );
        }

        nftRewards.unregisterTrigger(triggeredLimitId);
        storageT.unregisterPendingNftOrder(a.orderId);
    }

    // Shared code between market & limit callbacks
    function registerTrade(
        StorageInterface.Trade memory trade,
        uint nftId,
        uint limitIndex
    ) private returns (StorageInterface.Trade memory, uint) {
        AggregatorInterfaceV1_4 aggregator = storageT.priceAggregator();
        PairsStorageInterfaceV6 pairsStored = aggregator.pairsStorage();

        Values memory v;

        v.levPosWETH = trade.positionSizeWETH * trade.leverage;
        // v.tokenPriceWETH = aggregator.tokenPriceWETH();

        // 1. Charge referral fee (if applicable) and send WETH amount to vault
        // if (referrals.getTraderReferrer(trade.trader) != address(0)) {
        //     // Use this variable to store lev pos WETH for dev/gov fees after referral fees
        //     // and before volumeReferredWETH increases
        //     v.posWETH =
        //         (v.levPosWETH *
        //             (100 *
        //                 PRECISION -
        //                 referrals.getPercentOfOpenFeeP(trade.trader))) /
        //         100 /
        //         PRECISION;

        //     v.reward1 = referrals.distributePotentialReward(
        //         trade.trader,
        //         v.levPosWETH,
        //         pairsStored.pairOpenFeeP(trade.pairIndex),
        //         v.tokenPriceWETH
        //     );

        //     sendToVault(v.reward1, trade.trader);
        //     trade.positionSizeWETH -= v.reward1;

        //     emit ReferralFeeCharged(trade.trader, v.reward1);
        // }

        // // 2. Charge opening fee - referral fee (if applicable)
        // v.reward2 = storageT.handleDevGovFees(
        //     trade.pairIndex,
        //     (v.posWETH > 0 ? v.posWETH : v.levPosWETH),
        //     true,
        //     true
        // );

        // trade.positionSizeWETH -= v.reward2;

        // emit DevGovFeeCharged(trade.trader, v.reward2);

        // // 3. Charge NFT / SSS fee
        // v.reward2 =
        //     (v.levPosWETH *
        //         pairsStored.pairNftLimitOrderFeeP(trade.pairIndex)) /
        //     100 /
        //     PRECISION;
        // trade.positionSizeWETH -= v.reward2;

        // 3.1 Distribute NFT fee and send WETH amount to vault (if applicable)
        // if (nftId < 1500) {
        //     sendToVault(v.reward2, trade.trader);

        //     // Convert NFT bot fee from WETH to token value
        //     v.reward3 = (v.reward2 * PRECISION) / v.tokenPriceWETH;

        //     nftRewards.distributeNftReward(
        //         NftRewardsInterfaceV6_3_1.TriggeredLimitId(
        //             trade.trader,
        //             trade.pairIndex,
        //             limitIndex,
        //             StorageInterface.LimitOrder.OPEN
        //         ),
        //         v.reward3,
        //         v.tokenPriceWETH
        //     );
        //     storageT.increaseNftRewards(nftId, v.reward3);

        //     emit NftBotFeeCharged(trade.trader, v.reward2);

        //     // 3.2 Distribute SSS fee (if applicable)
        // } else {
        //     distributeStakingReward(trade.trader, v.reward2);
        // }

        // 4. Set trade final details
        trade.index = storageT.firstEmptyTradeIndex(
            trade.trader,
            trade.pairIndex
        );
        // trade.initialPosToken =
        //     (trade.positionSizeWETH * PRECISION) /
        //     v.tokenPriceWETH;

        trade.tp = correctTp(
            trade.openPrice,
            trade.leverage,
            trade.tp,
            trade.buy
        );
        trade.sl = correctSl(
            trade.openPrice,
            trade.leverage,
            trade.sl,
            trade.buy
        );

        // 5. Call other contracts
        pairInfos.storeTradeInitialAccFees(
            trade.trader,
            trade.pairIndex,
            trade.index,
            trade.buy
        );
        pairsStored.updateGroupCollateral(
            trade.pairIndex,
            trade.positionSizeWETH,
            trade.buy,
            true
        );
        borrowingFees.handleTradeAction(
            trade.trader,
            trade.pairIndex,
            trade.index,
            trade.positionSizeWETH * trade.leverage,
            true,
            trade.buy
        );

        // 6. Store final trade in storage contract
        storageT.storeTrade(
            trade,
            StorageInterface.TradeInfo(
                0,
                v.tokenPriceWETH,
                trade.positionSizeWETH * trade.leverage,
                0,
                0,
                false
            )
        );

        // 7. Store tradeLastUpdated
        LastUpdated storage lastUpdated = tradeLastUpdated[trade.trader][
            trade.pairIndex
        ][trade.index][TradeType.MARKET];
        uint32 currBlock = uint32(ChainUtils.getBlockNumber());
        lastUpdated.tp = currBlock;
        lastUpdated.sl = currBlock;
        lastUpdated.created = currBlock;

        return (trade, v.tokenPriceWETH);
    }

    function unregisterTrade(
        StorageInterface.Trade memory trade,
        bool marketOrder,
        int percentProfit, // PRECISION
        uint currentWETHPos, // 1e18
        uint openInterestWETH, // 1e18
        uint closingFeeWETH, // 1e18
        uint nftFeeWETH // 1e18 (= SSS reward if market order)
    ) private returns (uint WETHSentToTrader) {
        IToken vault = storageT.vault();

        // 1. Calculate net PnL (after all closing and holding fees)
        (WETHSentToTrader, ) = _getTradeValue(
            trade,
            currentWETHPos,
            percentProfit,
            closingFeeWETH + nftFeeWETH
        );

        // 2. Calls to other contracts
        borrowingFees.handleTradeAction(
            trade.trader,
            trade.pairIndex,
            trade.index,
            openInterestWETH,
            false,
            trade.buy
        );
        getPairsStorage().updateGroupCollateral(
            trade.pairIndex,
            openInterestWETH / trade.leverage,
            trade.buy,
            false
        );

        // 3. Unregister trade from storage

        storageT.unregisterTrade(trade.trader, trade.pairIndex, trade.index);
        // 4.1 If collateral in storage (opened after update)
        if (trade.positionSizeWETH > 0) {
            Values memory v;

            // 4.1.1 WETH vault reward
            // v.reward2 = (closingFeeWETH * WETHVaultFeeP) / 100;
            // transferFromStorageToAddress(address(this), v.reward2);
            // vault.distributeReward(v.reward2);

            // emit WETHVaultFeeCharged(trade.trader, v.reward2);

            // 4.1.2 SSS reward
            // v.reward3 = marketOrder
            //     ? nftFeeWETH + (closingFeeWETH * sssFeeP) / 100
            //     : (closingFeeWETH * sssFeeP) / 100;

            // distributeStakingReward(trade.trader, v.reward3);

            // 4.1.3 Take WETH from vault if winning trade
            // or send WETH to vault if losing trade
            uint WETHLeftInStorage = currentWETHPos - v.reward3 - v.reward2;
            if (WETHSentToTrader > WETHLeftInStorage) {
                vault.sendAssets(
                    WETHSentToTrader - WETHLeftInStorage,
                    trade.trader
                );
                transferFromStorageToAddress(trade.trader, WETHLeftInStorage);
            } else {
                sendToVault(WETHLeftInStorage - WETHSentToTrader, trade.trader);
                transferFromStorageToAddress(trade.trader, WETHSentToTrader);
            }

            // 4.2 If collateral in vault (opened before update)
        } else {
            vault.sendAssets(WETHSentToTrader, trade.trader);
        }
    }

    // Utils (external)
    function setTradeLastUpdated(
        SimplifiedTradeId calldata _id,
        LastUpdated memory _lastUpdated
    ) external onlyTrading {
        tradeLastUpdated[_id.trader][_id.pairIndex][_id.index][
            _id.tradeType
        ] = _lastUpdated;
    }

    function setTradeData(
        SimplifiedTradeId calldata _id,
        TradeData memory _tradeData
    ) external onlyTrading {
        tradeData[_id.trader][_id.pairIndex][_id.index][
            _id.tradeType
        ] = _tradeData;
    }

    // Utils (getters)
    function _getTradeValue(
        StorageInterface.Trade memory trade,
        uint currentWETHPos, // 1e18
        int percentProfit, // PRECISION
        uint closingFees // 1e18
    ) private returns (uint value, uint borrowingFee) {
        int netProfitP;

        (netProfitP, borrowingFee) = _getBorrowingFeeAdjustedPercentProfit(
            trade,
            currentWETHPos,
            percentProfit
        );
        value = pairInfos.getTradeValue(
            trade.trader,
            trade.pairIndex,
            trade.index,
            trade.buy,
            currentWETHPos,
            trade.leverage,
            netProfitP,
            closingFees
        );

        emit BorrowingFeeCharged(trade.trader, value, borrowingFee);
    }

    function _getBorrowingFeeAdjustedPercentProfit(
        StorageInterface.Trade memory trade,
        uint currentWETHPos, // 1e18
        int percentProfit // PRECISION
    ) private view returns (int netProfitP, uint borrowingFee) {
        borrowingFee = borrowingFees.getTradeBorrowingFee(
            BorrowingFeesInterface.BorrowingFeeInput(
                trade.trader,
                trade.pairIndex,
                trade.index,
                trade.buy,
                currentWETHPos,
                trade.leverage
            )
        );
        netProfitP =
            percentProfit -
            int((borrowingFee * 100 * PRECISION) / currentWETHPos);
    }

    function withinMaxLeverage(
        uint pairIndex,
        uint leverage
    ) private view returns (bool) {
        uint pairMaxLev = pairMaxLeverage[pairIndex];
        return
            pairMaxLev == 0
                ? leverage <= getPairsStorage().pairMaxLeverage(pairIndex)
                : leverage <= pairMaxLev;
    }

    function withinExposureLimits(
        uint pairIndex,
        bool buy,
        uint positionSizeWETH,
        uint leverage
    ) private view returns (bool) {
        uint levPositionSizeWETH = positionSizeWETH * leverage;

        return
            storageT.openInterestWETH(pairIndex, buy ? 0 : 1) +
                levPositionSizeWETH <=
            borrowingFees.getPairMaxOi(pairIndex) * 1e8 &&
            borrowingFees.withinMaxGroupOi(pairIndex, buy, levPositionSizeWETH);
    }

    function currentPercentProfit(
        uint openPrice,
        uint currentPrice,
        bool buy,
        uint leverage
    ) private view returns (int p) {
        int maxPnlP = int(MAX_GAIN_P) * int(PRECISION);

        p = openPrice > 0
            ? ((
                buy
                    ? int(currentPrice) - int(openPrice)
                    : int(openPrice) - int(currentPrice)
            ) *
                100 *
                int(PRECISION) *
                int(leverage)) / int(openPrice)
            : int(0);

        p = p > maxPnlP ? maxPnlP : p;
    }

    function correctTp(
        uint openPrice,
        uint leverage,
        uint tp,
        bool buy
    ) private view returns (uint) {
        if (
            tp == 0 ||
            currentPercentProfit(openPrice, tp, buy, leverage) ==
            int(MAX_GAIN_P) * int(PRECISION)
        ) {
            uint tpDiff = (openPrice * MAX_GAIN_P) / leverage / 100;

            return
                buy
                    ? openPrice + tpDiff
                    : (tpDiff <= openPrice ? openPrice - tpDiff : 0);
        }

        return tp;
    }

    function correctSl(
        uint openPrice,
        uint leverage,
        uint sl,
        bool buy
    ) private view returns (uint) {
        if (
            sl > 0 &&
            currentPercentProfit(openPrice, sl, buy, leverage) <
            int(MAX_SL_P) * int(PRECISION) * -1
        ) {
            uint slDiff = (openPrice * MAX_SL_P) / leverage / 100;

            return buy ? openPrice - slDiff : openPrice + slDiff;
        }

        return sl;
    }

    function marketExecutionPrice(
        uint price,
        uint spreadP,
        uint spreadReductionP,
        bool long
    ) private pure returns (uint) {
        uint priceDiff = (price *
            (spreadP - (spreadP * spreadReductionP) / 100)) /
            100 /
            PRECISION;

        return long ? price + priceDiff : price - priceDiff;
    }

    function _openTradePrep(
        OpenTradePrepInput memory c
    )
        private
        view
        returns (
            uint priceImpactP,
            uint priceAfterImpact,
            CancelReason cancelReason
        )
    {
        (priceImpactP, priceAfterImpact) = pairInfos.getTradePriceImpact(
            marketExecutionPrice(
                c.executionPrice,
                c.spreadP,
                c.spreadReductionP,
                c.buy
            ),
            c.pairIndex,
            c.buy,
            c.positionSize * c.leverage
        );

        uint maxSlippage = c.maxSlippageP > 0
            ? (c.wantedPrice * c.maxSlippageP) / 100 / PRECISION
            : c.wantedPrice / 100; // 1% by default

        cancelReason = isPaused
            ? CancelReason.PAUSED
            : (
                c.marketPrice == 0
                    ? CancelReason.MARKET_CLOSED
                    : (
                        c.buy
                            ? priceAfterImpact > c.wantedPrice + maxSlippage
                            : priceAfterImpact < c.wantedPrice - maxSlippage
                    )
                    ? CancelReason.SLIPPAGE
                    : (c.tp > 0 &&
                        (
                            c.buy
                                ? priceAfterImpact >= c.tp
                                : priceAfterImpact <= c.tp
                        ))
                    ? CancelReason.TP_REACHED
                    : (c.sl > 0 &&
                        (
                            c.buy
                                ? priceAfterImpact <= c.sl
                                : priceAfterImpact >= c.sl
                        ))
                    ? CancelReason.SL_REACHED
                    : !withinExposureLimits(
                        c.pairIndex,
                        c.buy,
                        c.positionSize,
                        c.leverage
                    )
                    ? CancelReason.EXPOSURE_LIMITS
                    : priceImpactP * c.leverage >
                        pairInfos.maxNegativePnlOnOpenP()
                    ? CancelReason.PRICE_IMPACT
                    : !withinMaxLeverage(c.pairIndex, c.leverage)
                    ? CancelReason.MAX_LEVERAGE
                    : CancelReason.NONE
            );
    }

    function getPendingMarketOrder(
        uint orderId
    ) private view returns (StorageInterface.PendingMarketOrder memory) {
        return storageT.reqID_pendingMarketOrder(orderId);
    }

    function getPairsStorage() private view returns (PairsStorageInterfaceV6) {
        return storageT.priceAggregator().pairsStorage();
    }

    function getOpenTrade(
        address trader,
        uint pairIndex,
        uint index
    ) private view returns (StorageInterface.Trade memory) {
        return storageT.openTrades(trader, pairIndex, index);
    }

    function getOpenTradeInfo(
        address trader,
        uint pairIndex,
        uint index
    ) private view returns (StorageInterface.TradeInfo memory) {
        return storageT.openTradesInfo(trader, pairIndex, index);
    }

    // Utils (private)
    function distributeStakingReward(address trader, uint amountWETH) private {
        transferFromStorageToAddress(address(this), amountWETH);
        staking.distributeRewardWETH(amountWETH);
        emit SssFeeCharged(trader, amountWETH);
    }

    function sendToVault(uint amountWETH, address trader) private {
        transferFromStorageToAddress(address(this), amountWETH);
        storageT.vault().receiveAssets(amountWETH, trader);
    }

    function transferFromStorageToAddress(address to, uint amountWETH) private {
        storageT.transferWETH(address(storageT), to, amountWETH);
    }

    // Public views
    function getAllPairsMaxLeverage() external view returns (uint[] memory) {
        uint len = getPairsStorage().pairsCount();
        uint[] memory lev = new uint[](len);

        for (uint i; i < len; ) {
            lev[i] = pairMaxLeverage[i];
            unchecked {
                ++i;
            }
        }

        return lev;
    }

    function giveApproval() external {
        storageT.WETH().approve(address(storageT.vault()), type(uint256).max);
    }
}
