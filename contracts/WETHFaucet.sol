// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/TokenInterface.sol";

contract WETHFaucet is OwnableUpgradeable {
    event sent(uint256 amount, address receiver);
    event TransferLimitUpdated(uint256 _limit);
    event TransferTimeLimitUpdated(uint256 _limit);

    uint256 public TransferLimit;

    TokenInterface WETH;

    mapping(address => bool) requestFulfilled;

    function Faucet_init(
        address owner,
        address _WETH,
        uint256 _transferLimit
    ) external initializer {
        _transferOwnership(owner);
        WETH = TokenInterface(_WETH);
        TransferLimit = _transferLimit;
    }

    function updateTransferLimit(uint256 _limit) external onlyOwner {
        TransferLimit = _limit;
        emit TransferLimitUpdated(_limit);
    }

    function send(address payable receiver) public {
        uint256 amountSent;

        require(!requestFulfilled[receiver], "Faucet: early requested Faucet");

        requestFulfilled[receiver] = true;

        WETH.mint(receiver, TransferLimit);

        emit sent(amountSent, receiver);
    }
}
