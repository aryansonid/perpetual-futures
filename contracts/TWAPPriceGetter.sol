// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";

abstract contract TWAPPriceGetter is Initializable {
    // Constants
    uint32 constant MIN_TWAP_PERIOD = 1 hours / 2;
    uint32 constant MAX_TWAP_PERIOD = 4 hours;

    uint public precision;
    address public token;

    // Adjustable parameters
    IUniswapV3Pool public uniV3Pool;
    uint32 public twapInterval;

    // State
    bool public isGnsToken0InLp;

    // Events
    event UniV3PoolUpdated(IUniswapV3Pool newValue);
    event TwapIntervalUpdated(uint32 newValue);

    function _TWAPPriceGetter__init(
        IUniswapV3Pool _uniV3Pool,
        address _token,
        uint32 _twapInterval,
        uint _precision
    ) internal onlyInitializing {
        require(
            address(_uniV3Pool) != address(0) &&
                _twapInterval >= MIN_TWAP_PERIOD &&
                _twapInterval <= MAX_TWAP_PERIOD &&
                _precision > 0,
            "WRONG_TWAP_CONSTRUCTOR"
        );

        uniV3Pool = _uniV3Pool;
        token = _token;
        twapInterval = _twapInterval;
        precision = _precision;

        isGnsToken0InLp = uniV3Pool.token0() == _token;
    }

    // Manage variables
    function _updateUniV3Pool(IUniswapV3Pool _uniV3Pool) internal {
        require(address(_uniV3Pool) != address(0), "WRONG_VALUE");
        uniV3Pool = _uniV3Pool;
        isGnsToken0InLp = uniV3Pool.token0() == token;
        emit UniV3PoolUpdated(_uniV3Pool);
    }

    function _updateTwapInterval(uint32 _twapInterval) internal {
        require(
            _twapInterval >= MIN_TWAP_PERIOD &&
                _twapInterval <= MAX_TWAP_PERIOD,
            "WRONG_VALUE"
        );
        twapInterval = _twapInterval;
        emit TwapIntervalUpdated(_twapInterval);
    }

    // Returns price with "precision" decimals
    // https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/OracleLibrary.sol
    function tokenPriceWETH() public view returns (uint price) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, ) = uniV3Pool.observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int56 twapIntervalInt = int56(int32(twapInterval));

        int24 arithmeticMeanTick = int24(
            tickCumulativesDelta / twapIntervalInt
        );
        // Always round to negative infinity
        if (
            tickCumulativesDelta < 0 &&
            (tickCumulativesDelta % twapIntervalInt != 0)
        ) arithmeticMeanTick--;

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(arithmeticMeanTick);
        price =
            (FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96) *
                precision) /
            2 ** 96;

        if (!isGnsToken0InLp) {
            price = precision ** 2 / price;
        }
    }
}
