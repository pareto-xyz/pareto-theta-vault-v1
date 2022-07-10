// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

/**
 * @notice Interface for Uniswap Router to swap tokens
 * @dev Taken from https://github.com/Uniswap/v3-periphery
 */
interface ISwapRouter {

    /**
     * @notice Input struct for `exactInputSingle`
     * @param tokenIn Address of the token to provide
     * @param tokenOut Address of the token to receive
     * @param fee Desired pool fee when routing
     * @param recipient Address of the recipient of token
     * @param deadline Timestamp in seconds when routing must occur by
     * @param amountIn Amount of `tokenIn` to provide for swapping
     * @param amountOutMinimum Minimum amount of `tokenOut` to receive from swap
     * @param sqrtPriceLimitX96 Optional limit on acceptable price (in 64.64)
     */
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Swaps `amountIn` of one token for as much as possible of another token
     * @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
     * @return amountOut The amount of the received token
     */
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}
