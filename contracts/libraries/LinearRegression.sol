// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {ABDKMath64x64} from "./ABDKMath64x64.sol";
import {Units} from "@primitivefi/rmm-core/contracts/libraries/Units.sol";

/**
 * @notice Linear regression model
 * @dev Does not fit a linear model. Only used for inference.
 */
library LinearRegression {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    using Units for int128;
    using Units for uint256;

    /**
     * @notice Compute `y_hat = x^Tw + b`
     * @param inputs One dimensional array of input features
     * @param weights One dimensional array of weight features
     * @param bias Scalar intercept term
     * @param inputSigns Boolean array where true is positive and false is negative
     * @param weightSigns Boolean array where true is positive and false is negative
     * @param biasSign Boolean where true is positive and false is negative
     * @param inputScaleFactor Unsigned 256-bit integer scaling factor for inputs e.g. 10^(18 - decimals())
     * @param weightScaleFactor Unsigned 256-bit integer scaling factor for weights + bias e.g. 10^(18 - decimals())
     * @return pred Predicted value, in same decimals as inputs
     * @return predSign Boolean where true is positive and false is negative
     */
    function predict(
        uint256[] memory inputs,
        uint256[] memory weights,
        uint256 bias,
        bool[] memory inputSigns,
        bool[] memory weightSigns,
        bool biasSign,
        uint256 inputScaleFactor,
        uint256 weightScaleFactor
    ) internal pure returns (
        uint256 pred,
        bool predSign
    ) {
        require(inputs.length == weights.length, "!length");

        // Restrict to lower than 10 dimensional
        require(inputs.length < 10, "too big");

        int128 inputX64;
        int128 weightX64;
        int128 predX64;

        for (uint256 i = 0; i < inputs.length; i++) {
            inputX64 = inputs[i].scaleToX64(inputScaleFactor);
            weightX64 = weights[i].scaleToX64(weightScaleFactor);
            if (!inputSigns[i]) {
                inputX64 = inputX64.neg();
            }
            if (!weightSigns[i]) {
                weightX64 = weightX64.neg();
            }
            predX64 = predX64.add(inputX64.mul(weightX64));
        }

        // Add a bias term
        int128 biasX64 = bias.scaleToX64(weightScaleFactor);
        if (!biasSign) {
            biasX64 = biasX64.neg();
        }
        predX64 = predX64.add(biasX64);
        predSign = !(predX64 < 0);  // false if negative
        if (!predSign) {
            predX64 = predX64.neg();
        }
        pred = predX64.scaleFromX64(inputScaleFactor);
        return (pred, predSign);
    }
}