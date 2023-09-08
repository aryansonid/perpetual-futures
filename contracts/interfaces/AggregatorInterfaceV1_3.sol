// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./AggregatorInterfaceV1_2.sol";
import "./ChainlinkFeedInterface.sol";

interface AggregatorInterfaceV1_3 is AggregatorInterfaceV1_2 {
    function linkPriceFeed() external view returns (ChainlinkFeedInterface);
}
