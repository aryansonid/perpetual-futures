// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface VaultInterfaceV5{
	function sendWETHToTrader(address, uint) external;
	function receiveWETHFromTrader(address, uint, uint) external;
	function currentBalanceWETH() external view returns(uint);
	function distributeRewardWETH(uint) external;
}