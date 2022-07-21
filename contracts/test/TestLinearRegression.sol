// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import {LinearRegression} from "../libraries/LinearRegression.sol";

/**
 * @notice Test contract to wrap around LinearRegression.sol library
 */
contract TestLinearRegression {
    function predict(
        uint256[2] memory inputs,
        uint256[2] memory weights,
        uint256 bias,
        bool[2] memory inputSigns,
        bool[2] memory weightSigns,
        bool biasSign,
        uint256 inputScaleFactor,
        uint256 weightScaleFactor
    ) external pure returns (uint256 pred, bool predSign) {
        return
            LinearRegression.predict(
                inputs,
                weights,
                bias,
                inputSigns,
                weightSigns,
                biasSign,
                inputScaleFactor,
                weightScaleFactor
            );
    }
}
