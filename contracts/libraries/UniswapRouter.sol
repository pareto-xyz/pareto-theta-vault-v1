// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "./SafeERC20.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {Path} from "@uniswap/v3-periphery/contracts/libraries/Path.sol";

/**
 * @notice Used to make swaps between tokens
 * Edited from https://github.com/ribbon-finance/ribbon-v2
 */
library UniswapRouter {
    using Path for bytes;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice Maximum amount of time to wait for swap
     */
    uint256 public swapBufferTime = 10 minutes;

    /**
     * @notice Check if the path set for swap is valid
     * @param swapPath is the swap path e.g. encodePacked(tokenIn, poolFee, tokenOut)
     * @param _tokenIn is the contract address of the correct tokenIn
     * @param _tokenOut is the contract address of the correct tokenOut
     * @param uniswapFactory is the contract address of UniswapV3 factory
     * @return isValidPath is whether the path is valid
     */
    function checkPath(
        bytes memory swapPath,
        address _tokenIn,
        address _tokenOut,
        address uniswapFactory
    ) internal view returns (bool isValidPath) {
        // Function checks if the tokenIn and tokenOut in the swapPath
        // matches the _tokenIn and _tokenOut specified.
        address tokenIn;
        address tokenOut;
        address tempTokenIn;
        uint24 fee;
        IUniswapV3Factory factory = IUniswapV3Factory(uniswapFactory);

        // Return early if swapPath is below the bare minimum (43)
        require(swapPath.length >= 43, "Path too short");
        // Return early if swapPath is above the max (66)
        // At worst we have 2 hops e.g. USDC > WETH > asset
        require(swapPath.length <= 66, "Path too long");

        // Decode the first pool in path
        (tokenIn, tokenOut, fee) = swapPath.decodeFirstPool();

        // Check to factory if pool exists
        require(
            factory.getPool(tokenIn, tokenOut, fee) != address(0),
            "Pool does not exist"
        );

        // Check next pool if multiple pools
        while (swapPath.hasMultiplePools()) {
            // Remove the first pool from path
            swapPath = swapPath.skipToken();
            // Check the next pool and update tokenOut
            (tempTokenIn, tokenOut, fee) = swapPath.decodeFirstPool();

            require(
                factory.getPool(tokenIn, tokenOut, fee) != address(0),
                "Pool does not exist"
            );
        }

        isValidPath = tokenIn == _tokenIn && tokenOut == _tokenOut;
        return isValidPath;
    }

    /**
     * @notice Swaps assets by calling UniswapV3 router
     * @param recipient is the address of recipient of the tokenOut
     * @param tokenIn is the address of the token given to the router
     * @param amountIn is the amount of tokenIn given to the router
     * @param minAmountOut is the minimum acceptable amount of tokenOut received from swap
     * @param router is the contract address of UniswapV3 router
     * @param swapPath is the swap path
     *  Compute this by abi.encodePacked(tokenIn, poolFee, tokenOut)
     * @return amountOut is the amount of tokenOut received from the swap
     */
    function swap(
        address recipient,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address router,
        bytes calldata swapPath
    ) internal returns (uint256 amountOut) {
        // Approve router to spend tokenIn
        IERC20(tokenIn).safeApprove(router, amountIn);

        // Swap assets using UniswapV3 router
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter
            .ExactInputParams({
                recipient: recipient,
                path: swapPath,
                deadline: block.timestamp.add(swapBufferTime),
                amountIn: amountIn,
                amountOutMinimum: minAmountOut
            });

        amountOut = ISwapRouter(router).exactInput(swapParams);
        return amountOut;
    }
}
