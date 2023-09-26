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

    mapping(uint256 => Observation) priceData;

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

    function feedPrice(uint256 tokenIndex, uint256 price) public {
        Observation memory last = priceData[tokenIndex];
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
        priceData[tokenIndex] = upadate;
    }

    function feedPriceArray(
        uint256[] calldata tokenIndexes,
        uint256[] calldata prices
    ) external {
        for (uint256 i; i < tokenIndexes.length; i++) {
            feedPrice(tokenIndexes[i], prices[i]);
        }
    }

    function getTWAP(
        uint256 tokenIndex
    ) external view returns (uint256 twapPrice) {
        Observation memory tokenPriceData = priceData[tokenIndex];
        require(tokenPriceData.secondsPerLiquidityCumulative != 0, "price feed not set");
        twapPrice =
            tokenPriceData.priceCumulative /
            tokenPriceData.secondsPerLiquidityCumulative;
    }
}
