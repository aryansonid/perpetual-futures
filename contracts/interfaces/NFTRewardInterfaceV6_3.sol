// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./StorageInterface.sol";

interface NftRewardsInterfaceV6_3_1 {
    struct TriggeredLimitId {
        address trader;
        uint pairIndex;
        uint index;
        StorageInterface.LimitOrder order;
    }
    enum OpenLimitOrderType {
        LEGACY,
        REVERSAL,
        MOMENTUM
    }

    function storeFirstToTrigger(
        TriggeredLimitId calldata,
        address,
        uint
    ) external;

    function storeTriggerSameBlock(TriggeredLimitId calldata, address) external;

    function unregisterTrigger(TriggeredLimitId calldata) external;

    function distributeNftReward(
        TriggeredLimitId calldata,
        uint,
        uint
    ) external;

    function openLimitOrderTypes(
        address,
        uint,
        uint
    ) external view returns (OpenLimitOrderType);

    function setOpenLimitOrderType(
        address,
        uint,
        uint,
        OpenLimitOrderType
    ) external;

    function triggered(TriggeredLimitId calldata) external view returns (bool);

    function timedOut(TriggeredLimitId calldata) external view returns (bool);

    function botInUse(bytes32) external view returns (bool);

    function getNftBotHashes(
        uint,
        address,
        uint,
        address,
        uint,
        uint
    ) external pure returns (bytes32, bytes32);

    function setNftBotInUse(bytes32, bytes32) external;

    function nftBotInUse(bytes32, bytes32) external view returns (bool);

    function linkToTokenRewards(uint, uint) external view returns (uint);
}
