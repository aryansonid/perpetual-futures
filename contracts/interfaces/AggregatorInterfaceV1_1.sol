// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./PairsStorageInterfaceV6.sol";
import "./NftRewardsInterfaceV6.sol";

interface AggregatorInterfaceV1_1 {
    enum OrderType {
        MARKET_OPEN,
        MARKET_CLOSE,
        LIMIT_OPEN,
        LIMIT_CLOSE,
        UPDATE_SL
    }

    function pairsStorage() external view returns (PairsStorageInterfaceV6);

    function nftRewards() external view returns (NftRewardsInterfaceV6);

    function getPrice(uint, OrderType, uint) external returns (uint);

    function tokenPriceWETH() external view returns (uint);

    function linkFee(uint, uint) external view returns (uint);

    function tokenWETHReservesLp() external view returns (uint, uint);

    function pendingSlOrders(uint) external view returns (PendingSl memory);

    function storePendingSlOrder(uint orderId, PendingSl calldata p) external;

    function unregisterPendingSlOrder(uint orderId) external;

    struct PendingSl {
        address trader;
        uint pairIndex;
        uint index;
        uint openPrice;
        bool buy;
        uint newSl;
    }
}
