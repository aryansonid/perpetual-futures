// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./TokenInterface.sol";
import "./NftInterfaceV5.sol";
import "./IToken.sol";
import "./AggregatorInterfaceV1.sol";
import "./IOracle.sol";
import "./PausableInterfaceV5.sol";

interface StorageInterface {
    enum LimitOrder {
        TP,
        SL,
        LIQ,
        OPEN,
        PAR_LIQ
    }
    struct Trade {
        address trader;
        uint pairIndex;
        uint index;
        uint initialPosToken; // 1e18
        uint positionSizeWETH; // 1e18
        uint openPrice; // PRECISION
        bool buy;
        uint leverage;
        uint tp; // PRECISION
        uint sl; // PRECISION
    }
    struct TradeInfo {
        uint tokenId;
        uint tokenPriceWETH; // PRECISION
        uint openInterestWETH; // 1e18
        uint tpLastUpdated;
        uint slLastUpdated;
        bool beingMarketClosed;
    }
    struct OpenLimitOrder {
        address trader;
        uint pairIndex;
        uint index;
        uint positionSize; // 1e18 (WETH or GFARM2)
        uint spreadReductionP;
        bool buy;
        uint leverage;
        uint tp; // PRECISION (%)
        uint sl; // PRECISION (%)
        uint minPrice; // PRECISION
        uint maxPrice; // PRECISION
        uint block;
        uint tokenId; // index in supportedTokens
    }
    struct PendingMarketOrder {
        Trade trade;
        uint block;
        uint wantedPrice; // PRECISION
        uint slippageP; // PRECISION (%)
        uint spreadReductionP;
        uint tokenId; // index in supportedTokens
    }
    struct PendingNftOrder {
        address nftHolder;
        uint nftId;
        address trader;
        uint pairIndex;
        uint index;
        LimitOrder orderType;
    }

    event OpenningInterestUpated(
        uint256 indexed pairIndex,
        uint256 indexed openingInterestShort,
        uint256 indexed openingInterestLong
    );

    event TradeOpen(Trade t);

    event TradeClose(Trade t);

    function PRECISION() external pure returns (uint);

    function gov() external view returns (address);

    function dev() external view returns (address);

    function WETH() external view returns (TokenInterface);

    function token() external view returns (TokenInterface);

    function linkErc677() external view returns (TokenInterface);

    function priceAggregator() external view returns (AggregatorInterfaceV1);

    function vault() external view returns (address);

    function trading() external view returns (PausableInterfaceV5);

    function callbacks() external view returns (PausableInterfaceV5);

    function handleTokens(address, uint, bool) external;

    function transferWETH(address, address, uint) external;

    function transferLinkToAggregator(address, uint, uint) external;

    function unregisterTrade(address, uint, uint) external;

    function unregisterPendingMarketOrder(uint, bool) external;

    function unregisterOpenLimitOrder(address, uint, uint) external;

    function hasOpenLimitOrder(
        address,
        uint,
        uint
    ) external view returns (bool);

    function storePendingMarketOrder(
        PendingMarketOrder memory,
        uint,
        bool
    ) external;

    function getOpenTrades(
        address,
        uint,
        uint
    ) external view returns (Trade memory);

    function getOpenTradesInfo(
        address,
        uint,
        uint
    ) external view returns (TradeInfo memory);

    function updateSl(address, uint, uint, uint) external;

    function updateTp(address, uint, uint, uint) external;

    function getOpenLimitOrder(
        address,
        uint,
        uint
    ) external view returns (OpenLimitOrder memory);

    function spreadReductionsP(uint) external view returns (uint);

    function storeOpenLimitOrder(OpenLimitOrder memory) external;

    function getPendingMarketOrder(
        uint
    ) external view returns (PendingMarketOrder memory);

    function storePendingNftOrder(PendingNftOrder memory, uint) external;

    function updateOpenLimitOrder(OpenLimitOrder calldata) external;

    function firstEmptyTradeIndex(address, uint) external view returns (uint);

    function firstEmptyOpenLimitIndex(
        address,
        uint
    ) external view returns (uint);

    function increaseNftRewards(uint, uint) external;

    function nftSuccessTimelock() external view returns (uint);

    function getPendingNftOrder(
        uint
    ) external view returns (PendingNftOrder memory);

    function updateTrade(Trade memory) external;

    function nftLastSuccess(uint) external view returns (uint);

    function unregisterPendingNftOrder(uint) external;

    function handleDevGovFees(uint, uint, bool, bool) external returns (uint);

    function distributeLpRewards(uint) external;

    function storeTrade(Trade memory, TradeInfo memory) external;

    function openLimitOrdersCount(address, uint) external view returns (uint);

    function openTradesCount(address, uint) external view returns (uint);

    function pendingMarketOpenCount(address, uint) external view returns (uint);

    function pendingMarketCloseCount(
        address,
        uint
    ) external view returns (uint);

    function maxSlP() external view returns (uint);

    function maxTradesPerPair() external view returns (uint);

    function pendingOrderIdsCount(address) external view returns (uint);

    function maxPendingMarketOrders() external view returns (uint);

    function openInterestWETH(uint, uint) external view returns (uint);

    function getPendingOrderIds(address) external view returns (uint[] memory);

    function nfts(uint) external view returns (NftInterfaceV5);

    // function fakeBlockNumber() external view returns (uint); // Testing

    function getGov() external view returns (address); // checking

    function mintWETH(address _to, uint _amount) external;

    function oracle() external view returns (IOracle);

    function getLiquidatableTrades()
        external
        view
        returns (
            uint[100] memory _orderTypes,
            address[100] memory traders,
            uint[100] memory pairIndexs,
            uint[100] memory indexs,
            uint256 index
        );
}
