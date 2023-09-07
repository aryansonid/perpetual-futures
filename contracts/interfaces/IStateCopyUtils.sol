// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./StorageInterfaceV5.sol";
import "./NFTRewardInterfaceV6_3.sol";

interface IStateCopyUtils {
    function getOpenLimitOrders()
        external
        view
        returns (StorageInterfaceV5.OpenLimitOrder[] memory);

    function nftRewards() external view returns (NftRewardsInterfaceV6_3_1);
}
