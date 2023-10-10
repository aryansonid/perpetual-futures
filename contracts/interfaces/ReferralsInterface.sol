// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ReferralsInterface {
    function registerPotentialReferrer(
        address trader,
        address referral
    ) external;

    function distributePotentialReward(
        address trader,
        uint volumeWETH,
        uint pairOpenFeeP,
        uint tokenPriceWETH
    ) external returns (uint);

    function getPercentOfOpenFeeP(address trader) external view returns (uint);

    function getTraderReferrer(
        address trader
    ) external view returns (address referrer);
}
