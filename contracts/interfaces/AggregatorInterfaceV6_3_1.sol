// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./AggregatorInterfaceV6_2.sol";
import "./ChainlinkFeedInterfaceV5.sol";

interface AggregatorInterfaceV6_3_1 is AggregatorInterfaceV6_2 {
    function linkPriceFeed() external view returns (ChainlinkFeedInterfaceV5);
}