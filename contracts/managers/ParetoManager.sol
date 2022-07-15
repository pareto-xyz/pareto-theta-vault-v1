// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IParetoManager} from "../interfaces/IParetoManager.sol";
import {Vault} from "../libraries/Vault.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {MoreReplicationMath} from "../libraries/MoreReplicationMath.sol";
import {console} from "hardhat/console.sol";

/**
 * @notice Automated management of Pareto Theta Vaults.
 *         Decides strike prices, volatility, and gamma through heuristics
 */
contract ParetoManager is IParetoManager, Ownable {
    using SafeMath for uint256;

    /************************************************
     * Immutables and Constants
     ***********************************************/

    /// @notice Address for the risky asset
    address public override risky;

    /// @notice Address for the stable asset
    address public override stable;

    /// @notice Address for the ChainLink oracle
    address public immutable chainlinkOracle;

    /// @notice Interface to interact with chainlink oracles
    AggregatorV3Interface internal chainlinkFeed;

    /// @notice True if the oracle returns risky in terms of stable.
    ///         False if oracle returns stable in terms of risky
    bool public immutable riskyFirst;

    /// @notice Minimum `riskyPerLp` and `stablePerLp` is 1%
    uint256 private constant MIN_PER_LP = 10000000000000000;

    /// @notice Maximum `riskyPerLp` and `stablePerLp` is 1%
    uint256 private constant MAX_PER_LP = 990000000000000000;

    /// @notice Default value for implied volatility is 80%
    uint32 private constant DEFAULT_SIGMA = 8000;

    /// @notice Default value for Primitive pool fees is 5%
    uint32 private constant DEFAULT_GAMMA = 9500;

    /// @notice Default value for Black Scholes delta is 20%
    uint32 private constant DEFAULT_DELTA = 2000;

    /************************************************
     * Constructor and initializers
     ***********************************************/

    /**
     * @param _risky Address for the risky token
     * @param _stable Address for the stable token
     * @param _chainlinkOracle Address for the risky-stable price oracle
     * @param _riskyFirst Reports if the oracle gives risky-stable or stable-risky price
     */
    constructor(
        address _risky,
        address _stable,
        address _chainlinkOracle,
        bool _riskyFirst
    ) {
        require(_risky != address(0), "!_risky");
        require(_stable != address(0), "!_stable");
        require(_chainlinkOracle != address(0), "!_chainlinkOracle");

        risky = _risky;
        stable = _stable;
        chainlinkOracle = _chainlinkOracle;
        chainlinkFeed = AggregatorV3Interface(_chainlinkOracle);
        riskyFirst = _riskyFirst;
    }

    /************************************************
     * Manager Operations
     ***********************************************/

    /**
     * @notice Price of one unit of stable token in risky using risky decimals
     * @dev Wrapper function around `_getOraclePrice`
     * @return price Amount of risky tokens for one unit of stable token
     */
    function getStableToRiskyPrice()
        external
        view
        override
        returns (uint256 price)
    {
        return _getOraclePrice(true);
    }

    /**
     * @notice Price of one unit of risky token in stable using stable decimals
     * @dev Wrapper function around `_getOraclePrice`
     * @return price Amount of stable tokens for one unit of risky token
     */
    function getRiskyToStablePrice()
        external
        view
        override
        returns (uint256 price)
    {
        return _getOraclePrice(false);
    }

    /**
     * @notice Return both stable-to-risky and risky-to-stable prices
     * @return stableToRiskyPrice Amount of risky tokens for one unit of stable token
     * @return riskyToStablePrice Amount of stable tokens for one unit of risky token
     */
    function getPrice()
        external
        view
        override
        returns (uint256 stableToRiskyPrice, uint256 riskyToStablePrice)
    {
        stableToRiskyPrice = _getOraclePrice(true);
        uint256 fixedOne = 10**uint256(IERC20(risky).decimals());
        riskyToStablePrice = (fixedOne * fixedOne) / stableToRiskyPrice;

        return (stableToRiskyPrice, riskyToStablePrice);
    }

    /**
     * @notice Return decimals used by the Chainlink Oracle
     * @return decimals Oracle uses a precision of 10**decimals
     */
    function getOracleDecimals() external view override returns (uint8) {
        return chainlinkFeed.decimals();
    }

    /**
     * @notice Calls Chainlink to get relative price between risky and stable asset.
     *         Returns the price of the stable asset in terms of the risky
     * @dev For example, USDC in terms of ETH
     * @param stableToRisky If True return oracle price for stable to risky asset.
     *                      If false, return oracle price for risky to stable asset
     * @return price Current exchange rate between the two tokens
     */
    function _getOraclePrice(bool stableToRisky)
        internal
        view
        returns (uint256 price)
    {
        (, int256 signedPrice, , , ) = chainlinkFeed.latestRoundData();

        require(signedPrice > 0, "!signedPrice");
        price = uint256(signedPrice);

        uint256 oracleDecimals = uint256(chainlinkFeed.decimals());

        // If riskyFirst is true, then the oracle returns price of risky
        // in terms of stable. We need to invert the price
        if ((riskyFirst && stableToRisky) || (!riskyFirst && !stableToRisky)) {
            uint256 fixedOne = 10**oracleDecimals; // unit
            price = (fixedOne * fixedOne) / price;
        }

        // Check if we need to change decimals to convert to out token
        uint256 outDecimals = stableToRisky
            ? uint256(IERC20(risky).decimals())
            : uint256(IERC20(stable).decimals());

        price = uint256(price).mul(10**outDecimals).div(10**oracleDecimals);
        return price;
    }

    /**
     * @notice Computes the strike price for the next pool by back-deriving strike
     *         from a known delta, implied volatility, and spot price
     * @dev Uses the same decimals as the stable token
     * @param sigma Implied volatility
     * @param tau Time to maturity in seconds.
     *            The conversion to years will happen within `MoreReplicationMath`
     * @param stableDecimals Decimals for the stable asset
     * @return strikePrice Relative price of risky in stable
     */
    function getNextStrikePrice(
        uint32 delta,
        uint32 sigma,
        uint256 tau,
        uint8 stableDecimals
    ) external view override returns (uint128 strikePrice) {
        uint256 scaleFactorStable = 10**(18 - stableDecimals);
        // Get price of risky in stable asset
        uint256 spotPrice = _getOraclePrice(false);
        uint256 rawStrike = MoreReplicationMath.getStrikeGivenDelta(
            delta,
            spotPrice,
            sigma,
            tau,
            scaleFactorStable
        );
        strikePrice = uint128(rawStrike);
        return strikePrice;
    }

    /**
     * @notice Computes the implied volatility for the next pool
     * @dev Currently hardcoded to 80%.
     *      Optimal choice is to match realized volatility in market
     * @return sigma Estimate of implied volatility
     */
    function getNextSigma() external pure override returns (uint32 sigma) {
        return DEFAULT_SIGMA;
    }

    /**
     * @notice Computes the gamma (or 1 - fee) for the next pool
     * @dev Currently hardcoded to 95% (or 5% fees).
     *      Choosing gamma effects the quality of replication
     * @return gamma Gamma for the next pool
     */
    function getNextGamma() external pure override returns (uint32 gamma) {
        return DEFAULT_GAMMA;
    }

    /**
     * @notice Computes the Black-Scholes delta used to create next pool
     * @dev Currently hardcoded to 20%. A higher value is more risky
     * @return delta Delta for the Black-Scholes model
     */
    function getNextDelta() external pure override returns (uint32 delta) {
        return DEFAULT_DELTA;
    }

    /**
     * @notice Computes the riskyForLp using oracle as spot price
     * @param spot Spot price in stable
     * @param strike Strike price in stable
     * @param sigma Implied volatility
     * @param tau Time to maturity in seconds.
     *            The conversion to years will happen within `MoreReplicationMath`
     * @param riskyDecimals Decimals for the risky asset
     * @param stableDecimals Decimals for the stable asset
     * @return riskyForLp R1 variable (in risky decimals)
     * @dev See page 14 of https://primitive.xyz/whitepaper-rmm-01.pdf.
     *      We cap the value within the range [0.1, 0.9]
     */
    function getRiskyPerLp(
        uint256 spot,
        uint128 strike,
        uint32 sigma,
        uint256 tau,
        uint8 riskyDecimals,
        uint8 stableDecimals
    ) external pure override returns (uint256 riskyForLp) {
        uint256 scaleFactorRisky = 10**(18 - riskyDecimals);
        uint256 scaleFactorStable = 10**(18 - stableDecimals);
        /// @dev: for a new pool, tau = maturity - current time
        riskyForLp = MoreReplicationMath.getRiskyPerLp(
            spot,
            uint256(strike),
            uint256(sigma),
            tau,
            scaleFactorRisky,
            scaleFactorStable
        );
        // TODO: check this with Primitive team; outside of these
        //       bounds, I get an error on `.create`
        if (riskyForLp < MIN_PER_LP) {
            riskyForLp = MIN_PER_LP;
        } else if (riskyForLp > MAX_PER_LP) {
            riskyForLp = MAX_PER_LP;
        }
        return riskyForLp;
    }

    /**
     * @notice Computes the exchange rate between stable asset and RMM-01 LP token.
     *         Assumes that `riskyPerLp` has been precomputed
     * @param invariantX64 Invariant for the pool
     * @param riskyPerLp Amount of risky token to trade for 1 LP token
     * @param strike Strike price in stable
     * @param sigma Implied volatility
     * @param tau Time to maturity in seconds
     * @param riskyDecimals Decimals for the risky asset
     * @param stableDecimals Decimals for the stable asset
     * @return stableForLp Amount of stable token to trade for 1 LP token
     */
    function getStablePerLp(
        int128 invariantX64,
        uint256 riskyPerLp,
        uint128 strike,
        uint32 sigma,
        uint256 tau,
        uint8 riskyDecimals,
        uint8 stableDecimals
    ) external pure override returns (uint256 stableForLp) {
        uint256 scaleFactorRisky = 10**(18 - riskyDecimals);
        uint256 scaleFactorStable = 10**(18 - stableDecimals);
        stableForLp = MoreReplicationMath.getStablePerLp(
            invariantX64,
            riskyPerLp,
            uint256(strike),
            uint256(sigma),
            tau,
            scaleFactorRisky,
            scaleFactorStable
        );
        if (stableForLp < MIN_PER_LP) {
            stableForLp = MIN_PER_LP;
        } else if (stableForLp > MAX_PER_LP) {
            stableForLp = MAX_PER_LP;
        }
        return stableForLp;
    }
}
