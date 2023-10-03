// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IOracle {
    function getPrice(
        uint256 tokenIndex
    ) external view returns (uint256 price, uint256 lastupdateTime);
}
