// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IParetoManager} from "../interfaces/IParetoManager.sol";
import {Vault} from "../libraries/Vault.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {ReplicationMath} from "../libraries/ReplicationMath.sol";
import {console} from "hardhat/console.sol";

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

    bool public immutable riskyFirst;

    // Multiplier for strike selection
    uint256 public override strikeMultiplier;

    // Strike multiplier has 2 decimal places e.g. 150 = 1.5x spot price
    uint256 private constant STRIKE_DECIMALS = 10**2;

    /************************************************
     * Constructor and initializers
     ***********************************************/

    /**
     * @param _strikeMultiplier is the multiplier on spot to set strike
     * @param _risky is the address for the risky token
     * @param _stable is the address for the stable token
     * @param _chainlinkOracle is the address for the risky-stable price oracle
     * @param _riskyFirst is true if the oracle gives price risky-stable
     *  and false if the oracle gives price stable-risky
     */
    constructor(
        uint256 _strikeMultiplier,
        address _risky,
        address _stable,
        address _chainlinkOracle,
        bool _riskyFirst
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
        riskyFirst = _riskyFirst;
    }

    /************************************************
     * Manager Operations
     ***********************************************/

    function getStableToRiskyPrice()
        external
        view
        override
        returns (uint256 price)
    {
        return _getOraclePrice(true);
    }

    function getRiskyToStablePrice()
        external
        view
        override
        returns (uint256 price)
    {
        return _getOraclePrice(false);
    }

    function getOracleDecimals() external view override returns (uint8) {
        return chainlinkFeed.decimals();
    }

    /**
     * @notice Calls Chainlink to get relative price between risky and stable asset
     *  Returns the price of the stable asset in terms of the risky
     *  For example, USDC in terms of ETH
     * @param stableToRisky if True return oracle price for stable to risky
     *  asset. If false, return oracle price for risky to stable asset
     * @return price is the current exchange rate between the two tokens
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
     * @notice Computes the strike price for the next pool by multiplying
     *  the current price - requires an oracle
     * @dev Uses the same decimals as the stable token
     * @return strikePrice is the relative price of risky in stable
     */
    function getNextStrikePrice()
        external
        view
        override
        returns (uint128 strikePrice)
    {
        // Get price of risky in stable asset
        uint256 spotPrice = _getOraclePrice(false);
        uint256 rawStrike = spotPrice.mul(strikeMultiplier).div(
            STRIKE_DECIMALS
        );
        strikePrice = uint128(rawStrike);
        return strikePrice;
    }

    /**
     * @notice Computes the volatility for the next pool
     * @return sigma is the implied volatility estimate
     */
    function getNextVolatility() external pure override returns (uint32 sigma) {
        sigma = 8000; // TODO - placeholder 80% sigma
        return sigma;
    }

    /**
     * @notice Computes the gamma (or 1 - fee) for the next pool
     * @return gamma is the Gamma for the next pool
     */
    function getNextGamma() external pure override returns (uint32 gamma) {
        gamma = 9500; // TODO - placeholder 99% gamma = 5% fee
        return gamma;
    }

    /**
     * @notice Computes the riskyForLp using oracle as spot price
     * @param strike is the strike price in stable
     * @param sigma is the implied volatility
     * @param maturity is the maturity timestamp in seconds
     *  The conversion to years will happen within `ReplicationMath`
     * @param riskyDecimals is the decimals for the risky asset
     * @param stableDecimals is the decimals for the stable asset
     * @return riskyForLp is the R1 variable (in risky decimals)
     * @dev See page 14 of https://primitive.xyz/whitepaper-rmm-01.pdf
     */
    function getRiskyPerLp(
        uint128 strike,
        uint32 sigma,
        uint32 maturity,
        uint8 riskyDecimals,
        uint8 stableDecimals
    ) external view override returns (uint256 riskyForLp) {
        uint256 scaleFactorRisky = 10**(18 - riskyDecimals);
        uint256 scaleFactorStable = 10**(18 - stableDecimals);
        /// @dev: for a new pool, tau = maturity - current time
        riskyForLp = ReplicationMath.getRiskyPerLp(
            uint256(_getOraclePrice(false)),
            uint256(strike),
            uint256(sigma),
            uint256(maturity).sub(block.timestamp),
            scaleFactorRisky,
            scaleFactorStable
        );
        return riskyForLp;
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
