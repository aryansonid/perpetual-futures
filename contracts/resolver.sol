// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {StorageInterface} from "./interfaces/StorageInterface.sol";
import {PausableInterfaceV5} from "./interfaces/PausableInterfaceV5.sol";

contract Resolver {
    StorageInterface public immutable storageT;

    constructor(StorageInterface _storageT) {
        storageT = _storageT;
    }

    function checker()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        (
            uint[100] memory _orderTypes,
            address[100] memory traders,
            uint[100] memory pairIndexs,
            uint[100] memory indexs,
            uint256 index
        ) = storageT.getLiquidatableTrades();

        canExec = _orderTypes[0] != 0;

        execPayload = abi.encodeCall(
            PausableInterfaceV5.executeLiquidations,
            (_orderTypes, traders, pairIndexs, indexs, index)
        );
    }
}
