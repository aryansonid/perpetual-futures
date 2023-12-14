// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/TokenInterface.sol";

contract WETHFaucet is OwnableUpgradeable {
    event sent(uint256 amount, address receiver);
    event TransferLimitUpdated(uint256 _limit);
    event TransferTimeLimitUpdated(uint256 _limit);

    uint256 public TransferLimit;
    uint256 public TransferTimeLimit;

    TokenInterface WETH;

    mapping(address => uint256) lastRequestTime;

    function Faucet_init(
        address owner,
        address _WETH,
        uint256 _transferLimit,
        uint256 _time
    ) external initializer {
        _transferOwnership(owner);
        WETH = TokenInterface(_WETH);
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

        WETH.mint(receiver, TransferLimit);

        emit sent(amountSent, receiver);
    }
}
