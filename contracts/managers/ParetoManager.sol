// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Vault} from "../libraries/Vault.sol";

/**
 * @notice Automated management of Pareto Theta Vaults
 * @notice Decides strike prices by percentages
 */
contract ParetoManager is Ownable {
    using SafeMath for uint256;

    /************************************************
     * Immutables and Constants
     ***********************************************/

     // multiplier for strike selection
    uint256 public strikeMultiplier;

    // Strike multiplier has 2 decimal places. For example: 150 = 1.5x spot price
    uint256 private constant STRIKE_DECIMALS = 10**2;

    constructor(uint256 _strikeMultiplier) {
        require(_strikeMultiplier > STRIKE_DECIMALS, "_strikeMultiplier < 1");
        strikeMultiplier = _strikeMultiplier;
    }

    /**
     * @notice Computes the strike price for the next pool by multiplying 
     * the current price - requires an oracle 
     * @notice TODO
     * --
     * @return strikePrice is the relative price of risky in stable
     */
    function getNextStrikePrice() 
        external 
        pure
        returns (uint256 strikePrice) 
    {
        return strikePrice; 
    }

    /**
     * @notice Computes the volatility for the next pool
     * @notice TODO
     * --
     * @return sigma is the implied volatility estimate
     */
    function getNextVolatility()
        external
        pure
        returns (uint32 sigma)
    {
        return sigma;
    }

    /**
     * @notice Set the multiplier for setting the strike price
     * --
     * @param _strikeMultiplier is the strike multiplier (decimals = 2)
     */
    function setStrikeMultiplier(uint256 _strikeMultiplier)
        external
        onlyOwner
    {
        require(_strikeMultiplier > STRIKE_DECIMALS, "_strikeMultiplier < 1");
        strikeMultiplier = _strikeMultiplier;
    }
}