// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IOracle {
    function getPrice(
        uint256 tokenIndex
    ) external view returns (uint256 price, uint256 lastupdateTime);

    function getFundingFee(
        uint256 tokenIndex
    ) external view returns (uint256 fee);
}
