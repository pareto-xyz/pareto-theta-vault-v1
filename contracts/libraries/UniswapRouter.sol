// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "./SafeERC20.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

/**
 * @notice Used to make swaps between tokens
 * Edited from https://github.com/ribbon-finance/ribbon-v2
 */
library UniswapRouter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice Maximum amount of time to wait for swap
     */
    uint256 public constant SWAP_BUFFER_TIME = 10 minutes;

    /**
     * @notice Swaps assets by calling UniswapV3 router
     * @param recipient is the address of recipient of the tokenOut
     * @param tokenIn is the address of the token given to the router
     * @param tokenOut is the address of the token received from the swap
     * @param poolFee is the amount of fee associated with the pool
     * @param amountIn is the amount of tokenIn given to the router
     * @param minAmountOut is the minimum acceptable amount of tokenOut received from swap
     * @param router is the contract address of UniswapV3 router
     * @return amountOut is the amount of tokenOut received from the swap
     */
    function swap(
        address recipient,
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn,
        uint256 minAmountOut,
        address router
    ) internal returns (uint256 amountOut) {
        // Approve router to spend tokenIn
        IERC20(tokenIn).safeApprove(router, amountIn);

        // Swap assets using UniswapV3 router
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: recipient,
                deadline: block.timestamp.add(SWAP_BUFFER_TIME),
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0
            });

        amountOut = ISwapRouter(router).exactInputSingle(swapParams);
        return amountOut;
    }
}
