// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract Oracle {
    struct Observation {
        // the block timestamp of the last updation
        uint256 lastUpdateblockTimestamp;
        // the price accumelator
        uint256 priceCumulative;
        // the seconds cummelated for every price update
        uint256 secondsPerLiquidityCumulative;
        // initialize time
        uint256 initializeTime;
    }

    mapping(address => Observation) priceData;

    function transformPriceData(
        Observation memory last,
        uint256 blockTimestamp,
        uint256 price
    ) private pure returns (Observation memory) {
        uint256 delta = blockTimestamp - last.lastUpdateblockTimestamp;
        return
            Observation({
                lastUpdateblockTimestamp: blockTimestamp,
                priceCumulative: last.priceCumulative + (price * delta),
                secondsPerLiquidityCumulative: last
                    .secondsPerLiquidityCumulative + delta,
                initializeTime: last.initializeTime
            });
    }

    function initializePriceData(
        uint256 blockTimestamp,
        uint256 price
    ) private pure returns (Observation memory) {
        return
            Observation({
                lastUpdateblockTimestamp: blockTimestamp,
                priceCumulative: price,
                secondsPerLiquidityCumulative: 1,
                initializeTime: blockTimestamp
            });
    }

    function feedPrice(address tokenAddress, uint256 price) public {
        Observation memory last = priceData[tokenAddress];
        uint256 initializatonDelta = block.timestamp - last.initializeTime;
        Observation memory upadate;
        if (
            initializatonDelta < 8 hours &&
            !(initializatonDelta == block.timestamp)
        ) {
            upadate = transformPriceData(last, block.timestamp, price);
        } else {
            upadate = initializePriceData(block.timestamp, price);
        }
        priceData[tokenAddress] = upadate;
    }

    function feedPriceArray(
        address[] calldata tokenAddress,
        uint256[] calldata prices
    ) external {
        for (uint256 i; i < tokenAddress.length; i++) {
            feedPrice(tokenAddress[i], prices[i]);
        }
    }

    function getTWAP(
        address tokenAddress
    ) external view returns (uint256 twapPrice) {
        Observation memory tokenPriceData = priceData[tokenAddress];
        twapPrice =
            tokenPriceData.priceCumulative /
            tokenPriceData.secondsPerLiquidityCumulative;
    }
}
