// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "./SafeERC20.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

/**
 * @notice Functions to make swaps between tokens
 * @dev Edited from https://github.com/ribbon-finance/ribbon-v2
 */
library UniswapRouter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice Maximum amount of time to wait for swap
    uint256 public constant SWAP_BUFFER_TIME = 10 minutes;

    /**
     * @notice Swaps assets by calling UniswapV3 router
     * @param recipient Address of recipient of the `tokenOut`
     * @param tokenIn Address of the token given to the router
     * @param tokenOut Address of the token received from the swap
     * @param poolFee Amount of fee associated with the pool
     * @param amountIn Amount of `tokenIn` given to the router
     * @param minAmountOut Minimum acceptable amount of `tokenOut` received from swap
     * @param router Contract address of UniswapV3 router
     * @return amountOut Amount of `tokenOut` received from the swap
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
        IERC20(tokenIn).safeIncreaseAllowance(router, amountIn);

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
