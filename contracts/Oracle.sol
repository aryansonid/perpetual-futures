// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Oracle is AccessControlUpgradeable {
    struct Observation {
        uint256 price;
        uint256 lastupdateTime;
    }

    bytes32 public constant PRICE_SETTER_ROLE = keccak256("PRICE_SETTER_ROLE");

    mapping(uint256 => Observation) priceData;

    function __Oracle_init(address priceSetter) external initializer {
        __AccessControl_init_unchained();
        __Context_init_unchained();
        _grantRole(PRICE_SETTER_ROLE, priceSetter);
        _setRoleAdmin(PRICE_SETTER_ROLE, PRICE_SETTER_ROLE);
    }

    function feedPrice(
        uint256 tokenIndex,
        uint256 price
    ) public onlyRole(PRICE_SETTER_ROLE) {
        _feedPrice(tokenIndex, price);
    }

    function feedPriceArray(
        uint256[] calldata tokenIndexes,
        uint256[] calldata prices
    ) external onlyRole(PRICE_SETTER_ROLE) {
        for (uint256 i; i < tokenIndexes.length; i++) {
            _feedPrice(tokenIndexes[i], prices[i]);
        }
    }

    function _feedPrice(uint256 tokenIndex, uint256 price) internal {
        require(price > 0, "Price can't be zero");
        priceData[tokenIndex] = Observation({
            price: price,
            lastupdateTime: block.timestamp
        });
    }

    function getPrice(
        uint256 tokenIndex
    ) external view returns (uint256 price, uint256 lastupdateTime) {
        Observation memory tokenPriceData = priceData[tokenIndex];
        return (tokenPriceData.price, tokenPriceData.lastupdateTime);
    }
}
