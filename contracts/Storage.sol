// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/StorageInterface.sol";
import "./interfaces/AggregatorInterfaceV1.sol";
import "./interfaces/PoolInterfaceV5.sol";
import "./interfaces/NftInterfaceV5.sol";
import "./interfaces/PausableInterfaceV5.sol";

contract Storage is StorageInterface, Initializable {
    // Constants
    uint public constant PRECISION = 1e10;
    bytes32 public constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    TokenInterface public WETH;
    IOracle public oracle;
    TokenInterface public constant linkErc677 =
        TokenInterface(0xb0897686c545045aFc77CF20eC7A532E3120E0F1);

    // Contracts (updatable)
    AggregatorInterfaceV1 public priceAggregator;
    PoolInterfaceV5 public pool;
    PausableInterfaceV5 public trading;
    PausableInterfaceV5 public callbacks;
    TokenInterface public token =
        TokenInterface(0x7075cAB6bCCA06613e2d071bd918D1a0241379E2);
    NftInterfaceV5[5] public nfts = [
        NftInterfaceV5(0xF9A4c522E327935BD1F5a338c121E14e4cc1f898),
        NftInterfaceV5(0x77cd42B925e1A82f41d852D6BE727CFc88fddBbC),
        NftInterfaceV5(0x3378AD81D09DE23725Ee9B9270635c97Ed601921),
        NftInterfaceV5(0x02e2c5825C1a3b69C0417706DbE1327C2Af3e6C2),
        NftInterfaceV5(0x2D266A94469d05C9e06D52A4D0d9C23b157767c2)
    ];
    address public vault;
    address public tokenWETHRouter;

    // Trading variables
    uint public maxTradesPerPair = 3;
    uint public maxTradesPerBlock = 5;
    uint public maxPendingMarketOrders = 5;
    uint public maxGainP = 900; // %
    uint public maxSlP = 80; // %
    uint public defaultLeverageUnlocked = 50; // x
    uint public nftSuccessTimelock = 50; // 50 blocks
    uint[5] public spreadReductionsP = [15, 20, 25, 30, 35]; // %

    // Gov & dev addresses (updatable)
    address public gov; //TODO need to change to our
    address public dev; //TODO need to change to our

    // Gov & dev fees
    uint public devFeesToken; // 1e18
    uint public devFeesWETH; // 1e18
    uint public govFeesToken; // 1e18
    uint public govFeesWETH; // 1e18

    // Stats
    uint public tokensBurned; // 1e18
    uint public tokensMinted; // 1e18
    uint public nftRewards; // 1e18

    // Enums
    // enum LimitOrder {
    //     TP,
    //     SL,
    //     LIQ,
    //     OPEN
    // }

    // Structs
    struct Trader {
        uint leverageUnlocked;
        address referral;
        uint referralRewardsTotal; // 1e18
    }
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
    // struct TradeInfo {
    //     uint tokenId;
    //     uint tokenPriceWETH; // PRECISION
    //     uint openInterestWETH; // 1e18
    //     uint tpLastUpdated;
    //     uint slLastUpdated;
    //     bool beingMarketClosed;
    // }
    // struct OpenLimitOrder {
    //     address trader;
    //     uint pairIndex;
    //     uint index;
    //     uint positionSize; // 1e18 (WETH or GFARM2)
    //     uint spreadReductionP;
    //     bool buy;
    //     uint leverage;
    //     uint tp; // PRECISION (%)
    //     uint sl; // PRECISION (%)
    //     uint minPrice; // PRECISION
    //     uint maxPrice; // PRECISION
    //     uint block;
    //     uint tokenId; // index in supportedTokens
    // }
    // struct PendingMarketOrder {
    //     Trade trade;
    //     uint block;
    //     uint wantedPrice; // PRECISION
    //     uint slippageP; // PRECISION (%)
    //     uint spreadReductionP;
    //     uint tokenId; // index in supportedTokens
    // }
    // struct PendingNftOrder {
    //     address nftHolder;
    //     uint nftId;
    //     address trader;
    //     uint pairIndex;
    //     uint index;
    //     LimitOrder orderType;
    // }

    // Supported tokens to open trades with
    address[] public supportedTokens;

    // User info mapping
    mapping(address => Trader) public traders;

    // Trades mappings
    mapping(address => mapping(uint => mapping(uint => Trade)))
        public openTrades;
    mapping(address => mapping(uint => mapping(uint => TradeInfo)))
        public openTradesInfo;
    mapping(address => mapping(uint => uint)) public openTradesCount;

    // Limit orders mappings
    mapping(address => mapping(uint => mapping(uint => uint)))
        public openLimitOrderIds;
    mapping(address => mapping(uint => uint)) public openLimitOrdersCount;
    OpenLimitOrder[] public openLimitOrders;

    // Pending orders mappings
    mapping(uint => PendingMarketOrder) public reqID_pendingMarketOrder;
    mapping(uint => PendingNftOrder) public reqID_pendingNftOrder;
    mapping(address => uint[]) public pendingOrderIds;
    mapping(address => mapping(uint => uint)) public pendingMarketOpenCount;
    mapping(address => mapping(uint => uint)) public pendingMarketCloseCount;

    // List of open trades & limit orders
    mapping(uint => address[]) public pairTraders;
    mapping(address => mapping(uint => uint)) public pairTradersId;

    // Current and max open interests for each pair
    mapping(uint => uint[3]) public openInterestWETH; // 1e18 [long,short,max]

    // Restrictions & Timelocks
    mapping(uint => uint) public tradesPerBlock;
    mapping(uint => uint) public nftLastSuccess;

    // List of allowed contracts => can update storage + mint/burn tokens
    mapping(address => bool) public isTradingContract;

    // Events
    event SupportedTokenAdded(address a);
    event TradingContractAdded(address a);
    event TradingContractRemoved(address a);
    event AddressUpdated(string name, address a);
    event NftsUpdated(NftInterfaceV5[5] nfts);
    event NumberUpdated(string name, uint value);
    event NumberUpdatedPair(string name, uint pairIndex, uint value);
    event SpreadReductionsUpdated(uint[5]);

    function initialize(
        address _WETH,
        address _gov,
        address _dev
    ) external initializer {
        WETH = TokenInterface(_WETH);
        gov = _gov;
        dev = _dev;
        token = TokenInterface(0x7075cAB6bCCA06613e2d071bd918D1a0241379E2);
        nfts = [
            NftInterfaceV5(0xF9A4c522E327935BD1F5a338c121E14e4cc1f898),
            NftInterfaceV5(0x77cd42B925e1A82f41d852D6BE727CFc88fddBbC),
            NftInterfaceV5(0x3378AD81D09DE23725Ee9B9270635c97Ed601921),
            NftInterfaceV5(0x02e2c5825C1a3b69C0417706DbE1327C2Af3e6C2),
            NftInterfaceV5(0x2D266A94469d05C9e06D52A4D0d9C23b157767c2)
        ];
        maxTradesPerPair = 3;
        maxTradesPerBlock = 5;
        maxPendingMarketOrders = 5;
        maxGainP = 900; // %
        maxSlP = 80; // %
        defaultLeverageUnlocked = 50; // x
        nftSuccessTimelock = 50; // 50 blocks
        spreadReductionsP = [15, 20, 25, 30, 35];
    }

    // Modifiers
    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }
    modifier onlyTrading() {
        require(
            isTradingContract[msg.sender],
            // &&
            //     token.hasRole(MINTER_ROLE, msg.sender)
            "here here"
        );
        _;
    }

    // Manage addresses
    function setGov(address _gov) external onlyGov {
        require(_gov != address(0));
        gov = _gov;
        emit AddressUpdated("gov", _gov);
    }

    function setDev(address _dev) external onlyGov {
        require(_dev != address(0));
        dev = _dev;
        emit AddressUpdated("dev", _dev);
    }

    function updateToken(TokenInterface _newToken) external onlyGov {
        require(trading.isPaused() && callbacks.isPaused(), "NOT_PAUSED");
        require(address(_newToken) != address(0));
        token = _newToken;
        emit AddressUpdated("token", address(_newToken));
    }

    function updateNfts(NftInterfaceV5[5] memory _nfts) external onlyGov {
        require(address(_nfts[0]) != address(0));
        nfts = _nfts;
        emit NftsUpdated(_nfts);
    }

    // Trading + callbacks contracts
    function addTradingContract(address _trading) external onlyGov {
        // require(token.hasRole(MINTER_ROLE, _trading), "NOT_MINTER"); /// TODO : need to have a gtoken type token of our own
        require(_trading != address(0));
        isTradingContract[_trading] = true;
        emit TradingContractAdded(_trading);
    }

    function removeTradingContract(address _trading) external onlyGov {
        require(_trading != address(0));
        isTradingContract[_trading] = false;
        emit TradingContractRemoved(_trading);
    }

    function addSupportedToken(address _token) external onlyGov {
        require(_token != address(0));
        supportedTokens.push(_token);
        emit SupportedTokenAdded(_token);
    }

    function setPriceAggregator(address _aggregator) external onlyGov {
        require(_aggregator != address(0));
        priceAggregator = AggregatorInterfaceV1(_aggregator);
        emit AddressUpdated("priceAggregator", _aggregator);
    }

    function setPool(address _pool) external onlyGov {
        require(_pool != address(0));
        pool = PoolInterfaceV5(_pool);
        emit AddressUpdated("pool", _pool);
    }

    function setVault(address _vault) external onlyGov {
        require(_vault != address(0));
        vault = _vault;
        emit AddressUpdated("vault", _vault);
    }

    function setTrading(address _trading) external onlyGov {
        require(_trading != address(0));
        trading = PausableInterfaceV5(_trading);
        emit AddressUpdated("trading", _trading);
    }

    function setCallbacks(address _callbacks) external onlyGov {
        require(_callbacks != address(0));
        callbacks = PausableInterfaceV5(_callbacks);
        emit AddressUpdated("callbacks", _callbacks);
    }

    function setTokenWETHRouter(address _tokenWETHRouter) external onlyGov {
        require(_tokenWETHRouter != address(0));
        tokenWETHRouter = _tokenWETHRouter;
        emit AddressUpdated("tokenWETHRouter", _tokenWETHRouter);
    }

    // Manage trading variables
    function setMaxTradesPerBlock(uint _maxTradesPerBlock) external onlyGov {
        require(_maxTradesPerBlock > 0);
        maxTradesPerBlock = _maxTradesPerBlock;
        emit NumberUpdated("maxTradesPerBlock", _maxTradesPerBlock);
    }

    function setMaxTradesPerPair(uint _maxTradesPerPair) external onlyGov {
        require(_maxTradesPerPair > 0);
        maxTradesPerPair = _maxTradesPerPair;
        emit NumberUpdated("maxTradesPerPair", _maxTradesPerPair);
    }

    function setMaxPendingMarketOrders(
        uint _maxPendingMarketOrders
    ) external onlyGov {
        require(_maxPendingMarketOrders > 0);
        maxPendingMarketOrders = _maxPendingMarketOrders;
        emit NumberUpdated("maxPendingMarketOrders", _maxPendingMarketOrders);
    }

    function setMaxGainP(uint _max) external onlyGov {
        require(_max >= 300);
        maxGainP = _max;
        emit NumberUpdated("maxGainP", _max);
    }

    function setDefaultLeverageUnlocked(uint _lev) external onlyGov {
        require(_lev > 0);
        defaultLeverageUnlocked = _lev;
        emit NumberUpdated("defaultLeverageUnlocked", _lev);
    }

    function setMaxSlP(uint _max) external onlyGov {
        require(_max >= 50);
        maxSlP = _max;
        emit NumberUpdated("maxSlP", _max);
    }

    function setNftSuccessTimelock(uint _blocks) external onlyGov {
        nftSuccessTimelock = _blocks;
        emit NumberUpdated("nftSuccessTimelock", _blocks);
    }

    function setSpreadReductionsP(uint[5] calldata _r) external onlyGov {
        require(
            _r[0] > 0 &&
                _r[1] > _r[0] &&
                _r[2] > _r[1] &&
                _r[3] > _r[2] &&
                _r[4] > _r[3]
        );
        spreadReductionsP = _r;
        emit SpreadReductionsUpdated(_r);
    }

    function setMaxOpenInterestWETH(
        uint _pairIndex,
        uint _newMaxOpenInterest
    ) external onlyGov {
        // Can set max open interest to 0 to pause trading on this pair only
        openInterestWETH[_pairIndex][2] = _newMaxOpenInterest;
        emit NumberUpdatedPair(
            "maxOpenInterestWETH",
            _pairIndex,
            _newMaxOpenInterest
        );
    }

    // Manage stored trades
    function storeTrade(
        Trade memory _trade,
        TradeInfo memory _tradeInfo
    ) external onlyTrading {
        _trade.index = firstEmptyTradeIndex(_trade.trader, _trade.pairIndex);
        openTrades[_trade.trader][_trade.pairIndex][_trade.index] = _trade;

        openTradesCount[_trade.trader][_trade.pairIndex]++;
        tradesPerBlock[block.number]++;

        if (openTradesCount[_trade.trader][_trade.pairIndex] == 1) {
            pairTradersId[_trade.trader][_trade.pairIndex] = pairTraders[
                _trade.pairIndex
            ].length;
            pairTraders[_trade.pairIndex].push(_trade.trader);
        }

        _tradeInfo.beingMarketClosed = false;
        openTradesInfo[_trade.trader][_trade.pairIndex][
            _trade.index
        ] = _tradeInfo;

        updateOpenInterestWETH(
            _trade.pairIndex,
            _tradeInfo.openInterestWETH,
            true,
            _trade.buy
        );

        emit TradeOpen(_trade);
    }

    function unregisterTrade(
        address trader,
        uint pairIndex,
        uint index
    ) external onlyTrading {
        Trade storage t = openTrades[trader][pairIndex][index];
        TradeInfo storage i = openTradesInfo[trader][pairIndex][index];
        if (t.leverage == 0) {
            return;
        }

        updateOpenInterestWETH(pairIndex, i.openInterestWETH, false, t.buy);

        if (openTradesCount[trader][pairIndex] == 1) {
            uint _pairTradersId = pairTradersId[trader][pairIndex];
            address[] storage p = pairTraders[pairIndex];

            p[_pairTradersId] = p[p.length - 1];
            pairTradersId[p[_pairTradersId]][pairIndex] = _pairTradersId;

            delete pairTradersId[trader][pairIndex];
            p.pop();
        }

        delete openTrades[trader][pairIndex][index];
        delete openTradesInfo[trader][pairIndex][index];

        openTradesCount[trader][pairIndex]--;
        tradesPerBlock[block.number]++;

        emit TradeClose(t);
    }

    // Manage pending market orders
    function storePendingMarketOrder(
        PendingMarketOrder memory _order,
        uint _id,
        bool _open
    ) external onlyTrading {
        pendingOrderIds[_order.trade.trader].push(_id);

        reqID_pendingMarketOrder[_id] = _order;
        reqID_pendingMarketOrder[_id].block = block.number;

        if (_open) {
            pendingMarketOpenCount[_order.trade.trader][
                _order.trade.pairIndex
            ]++;
        } else {
            pendingMarketCloseCount[_order.trade.trader][
                _order.trade.pairIndex
            ]++;
            openTradesInfo[_order.trade.trader][_order.trade.pairIndex][
                _order.trade.index
            ].beingMarketClosed = true;
        }
    }

    function unregisterPendingMarketOrder(
        uint _id,
        bool _open
    ) external onlyTrading {
        PendingMarketOrder memory _order = reqID_pendingMarketOrder[_id];
        uint[] storage orderIds = pendingOrderIds[_order.trade.trader];

        for (uint i = 0; i < orderIds.length; i++) {
            if (orderIds[i] == _id) {
                if (_open) {
                    pendingMarketOpenCount[_order.trade.trader][
                        _order.trade.pairIndex
                    ]--;
                } else {
                    pendingMarketCloseCount[_order.trade.trader][
                        _order.trade.pairIndex
                    ]--;
                    openTradesInfo[_order.trade.trader][_order.trade.pairIndex][
                        _order.trade.index
                    ].beingMarketClosed = false;
                }

                orderIds[i] = orderIds[orderIds.length - 1];
                orderIds.pop();

                delete reqID_pendingMarketOrder[_id];
                return;
            }
        }
    }

    // Manage open interest
    function updateOpenInterestWETH(
        uint _pairIndex,
        uint _leveragedPosWETH,
        bool _open,
        bool _long
    ) private {
        uint index = _long ? 0 : 1;
        uint[3] storage o = openInterestWETH[_pairIndex];
        o[index] = _open
            ? o[index] + _leveragedPosWETH
            : o[index] - _leveragedPosWETH;
        emit OpenningInterestUpated(_pairIndex, o[1], o[0]);
    }

    // Manage open limit orders
    function storeOpenLimitOrder(OpenLimitOrder memory o) external onlyTrading {
        o.index = firstEmptyOpenLimitIndex(o.trader, o.pairIndex);
        o.block = block.number;
        openLimitOrders.push(o);
        openLimitOrderIds[o.trader][o.pairIndex][o.index] =
            openLimitOrders.length -
            1;
        openLimitOrdersCount[o.trader][o.pairIndex]++;
    }

    function updateOpenLimitOrder(
        OpenLimitOrder calldata _o
    ) external onlyTrading {
        if (!hasOpenLimitOrder(_o.trader, _o.pairIndex, _o.index)) {
            return;
        }
        OpenLimitOrder storage o = openLimitOrders[
            openLimitOrderIds[_o.trader][_o.pairIndex][_o.index]
        ];
        o.positionSize = _o.positionSize;
        o.buy = _o.buy;
        o.leverage = _o.leverage;
        o.tp = _o.tp;
        o.sl = _o.sl;
        o.minPrice = _o.minPrice;
        o.maxPrice = _o.maxPrice;
        o.block = block.number;
    }

    function unregisterOpenLimitOrder(
        address _trader,
        uint _pairIndex,
        uint _index
    ) external onlyTrading {
        if (!hasOpenLimitOrder(_trader, _pairIndex, _index)) {
            return;
        }

        // Copy last order to deleted order => update id of this limit order
        uint id = openLimitOrderIds[_trader][_pairIndex][_index];
        openLimitOrders[id] = openLimitOrders[openLimitOrders.length - 1];
        openLimitOrderIds[openLimitOrders[id].trader][
            openLimitOrders[id].pairIndex
        ][openLimitOrders[id].index] = id;

        // Remove
        delete openLimitOrderIds[_trader][_pairIndex][_index];
        openLimitOrders.pop();

        openLimitOrdersCount[_trader][_pairIndex]--;
    }

    // Manage NFT orders
    function storePendingNftOrder(
        PendingNftOrder memory _nftOrder,
        uint _orderId
    ) external onlyTrading {
        reqID_pendingNftOrder[_orderId] = _nftOrder;
    }

    function unregisterPendingNftOrder(uint _order) external onlyTrading {
        delete reqID_pendingNftOrder[_order];
    }

    // Manage open trade
    function updateSl(
        address _trader,
        uint _pairIndex,
        uint _index,
        uint _newSl
    ) external onlyTrading {
        Trade storage t = openTrades[_trader][_pairIndex][_index];
        TradeInfo storage i = openTradesInfo[_trader][_pairIndex][_index];
        if (t.leverage == 0) {
            return;
        }
        t.sl = _newSl;
        i.slLastUpdated = block.number;
    }

    function updateTp(
        address _trader,
        uint _pairIndex,
        uint _index,
        uint _newTp
    ) external onlyTrading {
        Trade storage t = openTrades[_trader][_pairIndex][_index];
        TradeInfo storage i = openTradesInfo[_trader][_pairIndex][_index];
        if (t.leverage == 0) {
            return;
        }
        t.tp = _newTp;
        i.tpLastUpdated = block.number;
    }

    function updateTrade(Trade memory _t) external onlyTrading {
        // useful when partial adding/closing
        Trade storage t = openTrades[_t.trader][_t.pairIndex][_t.index];
        if (t.leverage == 0) {
            return;
        }
        t.initialPosToken = _t.initialPosToken;
        t.positionSizeWETH = _t.positionSizeWETH;
        t.openPrice = _t.openPrice;
        t.leverage = _t.leverage;
    }

    // Manage referrals
    function storeReferral(
        address _trader,
        address _referral
    ) external onlyTrading {
        Trader storage trader = traders[_trader];
        trader.referral = _referral != address(0) &&
            trader.referral == address(0) &&
            _referral != _trader
            ? _referral
            : trader.referral;
    }

    function increaseReferralRewards(
        address _referral,
        uint _amount
    ) external onlyTrading {
        traders[_referral].referralRewardsTotal += _amount;
    }

    // Manage rewards
    function distributeLpRewards(uint _amount) external onlyTrading {
        pool.increaseAccTokensPerLp(_amount);
    }

    function increaseNftRewards(
        uint _nftId,
        uint _amount
    ) external onlyTrading {
        nftLastSuccess[_nftId] = block.number;
        nftRewards += _amount;
    }

    // Unlock next leverage
    function setLeverageUnlocked(
        address _trader,
        uint _newLeverage
    ) external onlyTrading {
        traders[_trader].leverageUnlocked = _newLeverage;
    }

    // Manage dev & gov fees
    function handleDevGovFees(
        uint _pairIndex,
        uint _leveragedPositionSize,
        bool _WETH,
        bool _fullFee
    ) external onlyTrading returns (uint fee) {
        fee =
            (_leveragedPositionSize * priceAggregator.openFeeP(_pairIndex)) /
            PRECISION /
            100;
        if (!_fullFee) {
            fee /= 2;
        }

        if (_WETH) {
            govFeesWETH += fee;
            devFeesWETH += fee;
        } else {
            govFeesToken += fee;
            devFeesToken += fee;
        }

        fee *= 2;
    }

    function claimFees() external onlyGov {
        token.mint(dev, devFeesToken);
        token.mint(gov, govFeesToken);

        tokensMinted += devFeesToken + govFeesToken;

        WETH.transfer(gov, govFeesWETH);
        WETH.transfer(dev, devFeesWETH);

        devFeesToken = 0;
        govFeesToken = 0;
        devFeesWETH = 0;
        govFeesWETH = 0;
    }

    // Manage tokens
    function handleTokens(
        address _a,
        uint _amount,
        bool _mint
    ) external onlyTrading {
        if (_mint) {
            token.mint(_a, _amount);
            tokensMinted += _amount;
        } else {
            token.burn(_a, _amount);
            tokensBurned += _amount;
        }
    }

    function transferWETH(
        address _from,
        address _to,
        uint _amount
    ) external onlyTrading {
        if (_from == address(this)) {
            WETH.transfer(_to, _amount);
        } else {
            WETH.transferFrom(_from, _to, _amount);
        }
    }

    function mintWETH(address _to, uint _amount) external onlyTrading {
        WETH.mint(_to, _amount);
    }

    function transferLinkToAggregator(
        address _from,
        uint _pairIndex,
        uint _leveragedPosWETH
    ) external onlyTrading {
        linkErc677.transferFrom(
            _from,
            address(priceAggregator),
            priceAggregator.linkFee(_pairIndex, _leveragedPosWETH)
        );
    }

    // View utils functions
    function firstEmptyTradeIndex(
        address trader,
        uint pairIndex
    ) public view returns (uint index) {
        for (uint i = 0; i < maxTradesPerPair; i++) {
            if (openTrades[trader][pairIndex][i].leverage == 0) {
                index = i;
                break;
            }
        }
    }

    function firstEmptyOpenLimitIndex(
        address trader,
        uint pairIndex
    ) public view returns (uint index) {
        for (uint i = 0; i < maxTradesPerPair; i++) {
            if (!hasOpenLimitOrder(trader, pairIndex, i)) {
                index = i;
                break;
            }
        }
    }

    function hasOpenLimitOrder(
        address trader,
        uint pairIndex,
        uint index
    ) public view returns (bool) {
        if (openLimitOrders.length == 0) {
            return false;
        }
        OpenLimitOrder storage o = openLimitOrders[
            openLimitOrderIds[trader][pairIndex][index]
        ];
        return
            o.trader == trader && o.pairIndex == pairIndex && o.index == index;
    }

    // Additional getters
    function getReferral(address _trader) external view returns (address) {
        return traders[_trader].referral;
    }

    function getLeverageUnlocked(address _trader) external view returns (uint) {
        return traders[_trader].leverageUnlocked;
    }

    function pairTradersArray(
        uint _pairIndex
    ) external view returns (address[] memory) {
        return pairTraders[_pairIndex];
    }

    function getPendingOrderIds(
        address _trader
    ) external view returns (uint[] memory) {
        return pendingOrderIds[_trader];
    }

    function pendingOrderIdsCount(
        address _trader
    ) external view returns (uint) {
        return pendingOrderIds[_trader].length;
    }

    function getOpenLimitOrder(
        address _trader,
        uint _pairIndex,
        uint _index
    ) external view returns (OpenLimitOrder memory) {
        require(hasOpenLimitOrder(_trader, _pairIndex, _index));
        return openLimitOrders[openLimitOrderIds[_trader][_pairIndex][_index]];
    }

    function getOpenLimitOrders()
        external
        view
        returns (OpenLimitOrder[] memory)
    {
        return openLimitOrders;
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getSpreadReductionsArray() external view returns (uint[5] memory) {
        return spreadReductionsP;
    }

    function getGov() external view returns (address _gov) {
        return gov;
    }

    function setOracle(address _oracle) external {
        oracle = IOracle(_oracle);
    }

    function getOpenTrades(
        address trader,
        uint pairIndex,
        uint index
    ) external view returns (Trade memory) {
        return openTrades[trader][pairIndex][index];
    }

    function getOpenTradesInfo(
        address trader,
        uint pairIndex,
        uint index
    ) external view returns (TradeInfo memory) {
        return openTradesInfo[trader][pairIndex][index];
    }

    function getPendingMarketOrder(
        uint orderId
    ) external view returns (PendingMarketOrder memory) {
        return reqID_pendingMarketOrder[orderId];
    }

    function getPendingNftOrder(
        uint orderId
    ) external view returns (PendingNftOrder memory) {
        return reqID_pendingNftOrder[orderId];
    }
}
