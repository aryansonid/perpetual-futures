// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../interfaces/IArbSys.sol";

library ChainUtils {
    uint256 public constant ARBITRUM_MAINNET = 42161;
    uint256 public constant ARBITRUM_GOERLI = 421613;
    uint256 public constant ARBITRUM_SEPOLIA = 421614;

    IArbSys public constant ARB_SYS = IArbSys(address(100));

    function getBlockNumber() internal view returns (uint) {
        if (
            block.chainid == ARBITRUM_MAINNET ||
            block.chainid == ARBITRUM_GOERLI ||
            block.chainid == ARBITRUM_SEPOLIA
        ) {
            return ARB_SYS.arbBlockNumber();
        }

        return block.number;
    }

    function getUint48BlockNumber(
        uint blockNumber
    ) internal pure returns (uint48) {
        require(blockNumber <= type(uint48).max, "OVERFLOW");
        return uint48(blockNumber);
    }
}
