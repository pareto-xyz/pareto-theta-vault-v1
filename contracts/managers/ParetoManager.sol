// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

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

    /************************************************
     * Constructor and initializers
     ***********************************************/

    constructor(uint256 _strikeMultiplier) {
        require(_strikeMultiplier > STRIKE_DECIMALS, "_strikeMultiplier < 1");
        strikeMultiplier = _strikeMultiplier;
    }

    /************************************************
     * Manager Operations
     ***********************************************/

    /**
     * @notice Calls Uniswap to get relative price between risky and stable asset
     *  Assumes a pool exists between risky and stable asset
     * @param risky is the address of the risky token
     * @param stable is the address of the stable token
     * @return price is the current exchange rate between the two tokens
     */
    function getOraclePrice(address risky, address stable) 
        external
        pure
        returns (uint128 price) 
    {
        price = 1;  // TODO - placeholder constant
        return price;
    }

    /**
     * @notice Computes the strike price for the next pool by multiplying
     * the current price - requires an oracle
     * @return strikePrice is the relative price of risky in stable
     */
    function getNextStrikePrice() external pure returns (uint128 strikePrice) {
        strikePrice = 1000; // TODO - placeholder constant
        return strikePrice;
    }

    /**
     * @notice Computes the volatility for the next pool
     * @return sigma is the implied volatility estimate
     */
    function getNextVolatility() external pure returns (uint32 sigma) {
        sigma = 8000000; // TODO - placeholder constant
        return sigma;
    }

    /**
     * @notice Computes the gamma (or 1 - fee) for the next pool
     * @return gamma is the Gamma for the next pool
     */
    function getNextGamma() external pure returns (uint32 gamma) {
        gamma = 9900; // TODO - placeholder 99% gamma = 1% fee
        return gamma;
    }

    /**
     * @notice Set the multiplier for setting the strike price
     * @param _strikeMultiplier is the strike multiplier (decimals = 2)
     */
    function setStrikeMultiplier(uint256 _strikeMultiplier) external onlyOwner {
        require(_strikeMultiplier > STRIKE_DECIMALS, "_strikeMultiplier < 1");
        strikeMultiplier = _strikeMultiplier;
    }
}
