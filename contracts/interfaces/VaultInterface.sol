// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface VaultInterface {
    function sendWETHToTrader(address, uint) external;

    function receiveWETHFromTrader(address, uint, uint) external;

    function currentBalanceWETH() external view returns (uint);

    function distributeRewardWETH(uint) external;
}
