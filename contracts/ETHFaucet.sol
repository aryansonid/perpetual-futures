// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ETHFaucet is OwnableUpgradeable {
    event sent(uint256 amount, address receiver);
    event TransferLimitUpdated(uint256 _limit);
    event TransferTimeLimitUpdated(uint256 _limit);

    uint256 public TransferLimit;
    uint256 public TransferTimeLimit;

    mapping(address => uint256) lastRequestTime;

    function Faucet_init(
        address owner,
        uint256 _transferLimit,
        uint256 _time
    ) external initializer {
        _transferOwnership(owner);
        TransferLimit = _transferLimit;
        TransferTimeLimit = _time;
    }

    function updateTransferLimit(uint256 _limit) external onlyOwner {
        TransferLimit = _limit;
        emit TransferLimitUpdated(_limit);
    }

    function updateTransferTimeLimit(uint256 _limit) external onlyOwner {
        TransferTimeLimit = _limit;
        emit TransferTimeLimitUpdated(_limit);
    }

    function send(address payable receiver) public {
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
