// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./PairsStorageInterfaceV6.sol";
import "./ChainlinkFeedInterface.sol";

interface AggregatorInterfaceV1_4 {
    enum OrderType {
        MARKET_OPEN,
        MARKET_CLOSE,
        LIMIT_OPEN,
        LIMIT_CLOSE
    }

    function pairsStorage() external view returns (PairsStorageInterfaceV6);

    function getPrice(uint, OrderType, uint, uint) external returns (uint);

    function tokenPriceWETH() external returns (uint);

    function linkFee(uint, uint) external view returns (uint);

    function openFeeP(uint) external view returns (uint);

    function linkPriceFeed() external view returns (ChainlinkFeedInterface);
}
