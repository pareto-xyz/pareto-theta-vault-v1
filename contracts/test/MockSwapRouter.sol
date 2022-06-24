// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

contract MockSwapRouter is ISwapRouter {
    function exactInput(ExactInputParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        // Spoof by just returning amountIn (1 for 1 trade)
        amountOut = params.amountIn;
        return amountOut;
    }
}
