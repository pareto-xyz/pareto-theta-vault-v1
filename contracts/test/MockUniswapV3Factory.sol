// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";

contract MockAggregatorV3 is IUniswapV3Factory {
    address public savedPool;

    function setPool(address pool) public {
        savedPool = pool;
    }

    /** 
     * @param tokenA The contract address of either token0 or token1
     * @param tokenB The contract address of the other token
     * @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
     * @return The pool address
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) 
        external 
        view 
        override 
        returns (address)
    {
        return savedPool;
    }
}