// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IParetoManager} from "../interfaces/IParetoManager.sol";
import {Vault} from "../libraries/Vault.sol";

/**
 * @notice Automated management of Pareto Theta Vaults
 * @notice Decides strike prices by percentages
 */
contract ParetoManager is IParetoManager, Ownable {
    using SafeMath for uint256;

    /************************************************
     * Immutables and Constants
     ***********************************************/

    // Address for the risky asset
    address public override risky;

    // Address for the stable asset
    address public override stable;

    /** 
     * @notice Address for the ChainLink oracle
     * 
     * Network: Kovan
     * USDC-ETH: 0x64EaC61A2DFda2c3Fa04eED49AA33D021AeC8838
     * 
     * Network: Rinkeby
     * USDC-ETH: 0xdCA36F27cbC4E38aE16C4E9f99D39b42337F6dcf
     * 
     * Network: MainNet
     * USDC-ETH: 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4
     */
    address public immutable chainlinkOracle;

    AggregatorV3Interface internal chainlinkFeed;

    // Multiplier for strike selection
    uint256 public strikeMultiplier;

    // Strike multiplier has 2 decimal places. For example: 150 = 1.5x spot price
    uint256 private constant STRIKE_DECIMALS = 10**2;

    /************************************************
     * Constructor and initializers
     ***********************************************/

    /**
     * @param _strikeMultiplier is the multiplier on spot to set strike
     * @param _risky is the address for the risky token
     * @param _stable is the address for the stable token
     * @param _chainlinkOracle is the address for the risky-stable price oracle
     */
    constructor(
        uint256 _strikeMultiplier,
        address _risky,
        address _stable,
        address _chainlinkOracle
    ) {
        require(
            _strikeMultiplier > STRIKE_DECIMALS, 
            "_strikeMultiplier too small"
        );
        require(_risky != address(0), "!_risky");
        require(_stable != address(0), "!_stable");
        require(_chainlinkOracle != address(0), "!_chainlinkOracle");

        strikeMultiplier = _strikeMultiplier;
        risky = _risky;
        stable = _stable;
        chainlinkOracle = _chainlinkOracle;
        chainlinkFeed = AggregatorV3Interface(_chainlinkOracle);
    }

    /************************************************
     * Manager Operations
     ***********************************************/

    /**
     * External endpoint for _getOraclePrice
     */
    function getOraclePrice() external view override returns (uint256 price) {
        return _getOraclePrice();
    }

    /**
     * @notice Calls Uniswap to get relative price between risky and stable asset
     *  Assumes a pool exists between risky and stable asset
     * @return price is the current exchange rate between the two tokens
     */
    function _getOraclePrice() public view returns (uint256 price) {
        (
            /* uint80 roundID */,
            int256 rawPrice,
            /* uint startedAt */,
            /* uint timeStamp */,
            /* uint80 answeredInRound */
        ) = chainlinkFeed.latestRoundData();
        require(rawPrice > 0, "!rawPrice");
        price = uint256(rawPrice);  // make unsigned
        return price;
    }

    /**
     * @notice Computes the strike price for the next pool by multiplying
     * the current price - requires an oracle
     * @return strikePrice is the relative price of risky in stable
     */
    function getNextStrikePrice() 
        external 
        view 
        override
        returns (uint256 strikePrice) 
    {
        uint256 spotPrice = _getOraclePrice();
        strikePrice = spotPrice.mul(strikeMultiplier).div(STRIKE_DECIMALS);
        return strikePrice;
    }

    /**
     * @notice Computes the volatility for the next pool
     * @return sigma is the implied volatility estimate
     */
    function getNextVolatility()
        external 
        view 
        override
        returns (uint256 sigma) 
    {
        sigma = 8000000; // TODO - placeholder constant
        return sigma;
    }

    /**
     * @notice Computes the gamma (or 1 - fee) for the next pool
     * @return gamma is the Gamma for the next pool
     */
    function getNextGamma()
        external
        view 
        override
        returns (uint256 gamma) 
    {
        gamma = 9900; // TODO - placeholder 99% gamma = 1% fee
        return gamma;
    }

    /**
     * @notice Set the multiplier for setting the strike price
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
