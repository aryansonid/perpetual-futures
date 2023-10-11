// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Oracle is AccessControlUpgradeable {
    struct Observation {
        uint256 price;
        uint256 lastupdateTime;
    }

    struct FundingFeeObservation {
        uint256 price;
        uint256 lastupdateTime;
        uint256 lastupdateBlockNumber;
        int fundingFeeRate; // funding fee rate per block
    }

    bytes32 public constant PRICE_SETTER_ROLE = keccak256("PRICE_SETTER_ROLE");
    uint constant PRECISION = 1e10;

    uint256 public fundingFeeEpoch;

    mapping(uint256 => Observation) priceData;
    mapping(uint256 => FundingFeeObservation) fundinFeeData;

    function __Oracle_init(
        address priceSetter,
        uint256 _fundingFeeEpoch
    ) external initializer {
        __AccessControl_init_unchained();
        __Context_init_unchained();
        _grantRole(PRICE_SETTER_ROLE, priceSetter);
        _setRoleAdmin(PRICE_SETTER_ROLE, PRICE_SETTER_ROLE);
        fundingFeeEpoch = _fundingFeeEpoch;
    }

    function feedPrice(
        uint256 tokenIndex,
        uint256 price
    ) public onlyRole(PRICE_SETTER_ROLE) {
        _feedPrice(tokenIndex, price);
        _feedFundingFeeData(tokenIndex, price);
    }

    function feedPriceArray(
        uint256[] calldata tokenIndexes,
        uint256[] calldata prices
    ) external onlyRole(PRICE_SETTER_ROLE) {
        for (uint256 i; i < tokenIndexes.length; i++) {
            _feedPrice(tokenIndexes[i], prices[i]);
            _feedFundingFeeData(tokenIndexes[i], prices[i]);
        }
    }

    function _feedPrice(uint256 tokenIndex, uint256 price) internal {
        require(price > 0, "Price can't be zero");
        priceData[tokenIndex] = Observation({
            price: price,
            lastupdateTime: block.timestamp
        });
    }

    function _feedFundingFeeData(uint256 tokenIndex, uint256 price) internal {
        require(price > 0, "Price can't be zero");
        FundingFeeObservation memory data = fundinFeeData[tokenIndex];
        bool feedData = data.lastupdateTime == 0;
        bool updateFee = (fundingFeeEpoch <=
            block.timestamp - data.lastupdateTime) && data.lastupdateTime != 0;
        if (feedData) {
            fundinFeeData[tokenIndex] = FundingFeeObservation({
                price: price,
                lastupdateTime: block.timestamp,
                lastupdateBlockNumber: block.number,
                fundingFeeRate: 0
            });
        }
        if (updateFee) {
            int256 rate = (((int(price) - int(data.price))) * int(PRECISION)) /
                int(data.price);
            int fee = rate / int(block.number - data.lastupdateBlockNumber);
            fundinFeeData[tokenIndex] = FundingFeeObservation({
                price: price,
                lastupdateTime: block.timestamp,
                lastupdateBlockNumber: block.number,
                fundingFeeRate: fee
            });
        }
    }

    function getPrice(
        uint256 tokenIndex
    ) external view returns (uint256 price, uint256 lastupdateTime) {
        Observation memory tokenPriceData = priceData[tokenIndex];
        return (tokenPriceData.price, tokenPriceData.lastupdateTime);
    }

    // set EPOCH as seconds in the period
    function setFundingFeeEPOCH(uint256 _seconds) external {
        fundingFeeEpoch = _seconds;
    }

    function getFundingFee(
        uint256 tokenIndex
    ) external view returns (uint256 fee) {
        if (fundinFeeData[tokenIndex].fundingFeeRate < 0) {
            fee = uint256(fundinFeeData[tokenIndex].fundingFeeRate * -1);
        } else {
            fee = uint256(fundinFeeData[tokenIndex].fundingFeeRate);
        }
    }
}
