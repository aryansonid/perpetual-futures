// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./StorageInterface.sol";
import "./NFTRewardInterfaceV6_3.sol";

interface IStateCopyUtils {
    function getOpenLimitOrders()
        external
        view
        returns (StorageInterface.OpenLimitOrder[] memory);

    function nftRewards() external view returns (NftRewardsInterfaceV6_3_1);
}
