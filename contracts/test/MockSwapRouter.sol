// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {IMockERC20} from "../test/IMockERC20.sol";

contract MockSwapRouter is ISwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        // Spoof by just returning the minimum amount asked for
        amountOut = params.amountOutMinimum;

        // Actually mint and burn tokens
        // TODO: this does it immediately. We should simulate a delay
        IMockERC20(params.tokenIn).burn(params.recipient, params.amountIn);
        IMockERC20(params.tokenOut).mint(params.recipient, amountOut);

        return amountOut;
    }
}
