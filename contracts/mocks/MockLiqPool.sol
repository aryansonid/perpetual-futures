pragma solidity 0.8.14;

contract MockLiqPool {
    address public token0;

    constructor(address _token) {
        token0 = _token;
    }
}
