// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Faucet is OwnableUpgradeable {
    event sent(uint256 amount, address receiver);

    uint256 constant TransferLimit = 5e17; //0.5 eth
    uint256 constant TransferTimeLimit = 1 days;

    mapping(address => uint256) lastRequestTime;

    function Faucet_init(address owner) external initializer {
        _transferOwnership(owner);
    }

    function send(address payable receiver) public payable {
        uint256 amountSent;

        require(
            block.timestamp - lastRequestTime[receiver] >= TransferTimeLimit,
            "Faucet: early to get faucets"
        );

        lastRequestTime[receiver] = block.timestamp;

        if (address(this).balance > TransferLimit) {
            amountSent = TransferLimit;
            receiver.transfer(TransferLimit);
        } else {
            amountSent = (address(this).balance);
            receiver.transfer(address(this).balance);
        }

        emit sent(amountSent, receiver);
    }

    function withdraw(address payable receiver) external onlyOwner {
        receiver.transfer(address(this).balance);
    }
}
