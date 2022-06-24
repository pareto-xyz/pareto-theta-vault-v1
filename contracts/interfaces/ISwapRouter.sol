// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;
pragma abicoder v2;

/**
 * Source: https://github.com/Uniswap/v3-periphery
 * @title Router token swapping functionality
 * @notice Functions for swapping tokens via Uniswap V3
 */
interface ISwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /**
     * @notice Swaps `amountIn` of one token for as much as possible of
     *  another along the specified path
     * @param params The parameters necessary for the multi-hop swap,
     *  encoded as `ExactInputParams` in calldata
     * @return amountOut The amount of the received token
     */
    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}
