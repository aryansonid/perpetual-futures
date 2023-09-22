// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ChainlinkFeedInterface {
    function latestRoundData()
        external
        view
        returns (uint80, int, uint, uint, uint80);
}
