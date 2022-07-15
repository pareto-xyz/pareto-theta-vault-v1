import hre, { ethers } from "hardhat";
import { Contract } from "ethers";
import { parseWei } from "web3-units";
import expect from "./shared/expect";
import { fromBn, toBn } from "evm-bn";
import { normalCDF } from "./shared/utils";

let manager: Contract;
let risky: Contract;
let stable: Contract;
let aggregatorV3: Contract;
let riskyDecimals: number;
let stableDecimals: number;

describe("ParetoManager contract", function () {
  beforeEach(async function () {
    const [deployer] = await hre.ethers.getSigners();

    // Create ERC20 for risky and stable tokens
    const MockERC20 = await ethers.getContractFactory("MockERC20", deployer);
    risky = await MockERC20.deploy();
    stable = await MockERC20.deploy();

    // Create and deploy Mock Chainlink protocol
    const AggregatorV3 = await ethers.getContractFactory(
      "MockAggregatorV3",
      deployer
    );
    aggregatorV3 = await AggregatorV3.deploy();
    const decimals = await aggregatorV3.decimals();
    // initialize as equal prices
    aggregatorV3.setLatestAnswer(parseWei("1", decimals).raw);

    // Save decimals to globals
    riskyDecimals = await risky.decimals();
    stableDecimals = await stable.decimals();

    // Load the manager
    const ParetoManager = await hre.ethers.getContractFactory("ParetoManager");
    manager = await ParetoManager.deploy(
      risky.address,
      stable.address,
      aggregatorV3.address,
      false
    );
  });
  describe("asset getters", function () {
    /**
     * @notice Checks that the manager's stored risky asset is correct
     */
    it("correct default risky", async function () {
      expect(await manager.risky()).to.be.equal(risky.address);
    });
    /**
     * @notice Checks that the manager's stored stable asset is correct
     */
    it("correct default stable", async function () {
      expect(await manager.stable()).to.be.equal(stable.address);
    });
  });
  describe("function getters", function () {
    /**
     * @notice Checks that the manager's oracle decimals is expected
     */
    it("correct oracle decimals", async function () {
      let oracleDecimals = await aggregatorV3.decimals();
      expect(await manager.getOracleDecimals()).to.be.equal(oracleDecimals);
    });
    /**
     * @notice Checks that for a unit of stable asset priced as a unit
     * of risky asset, we obtain one risky in return
     */
    it("correct one-to-one stable to risky price", async function () {
      // Set oracle price to be 1 stable for 1 risky
      aggregatorV3.setLatestAnswer(
        parseWei("1", await aggregatorV3.decimals()).raw
      );
      expect(
        fromBn(await manager.getStableToRiskyPrice(), riskyDecimals)
      ).to.be.equal("1");
    });
    /**
     * @notice Checks that for a unit of risky asset priced as a unit
     * of stable asset, we obtain one stable in return
     */
    it("correct one-to-one risky to stable price", async function () {
      // Set oracle price to be 1 risky for 1 stable
      aggregatorV3.setLatestAnswer(
        parseWei("1", await aggregatorV3.decimals()).raw
      );
      expect(
        fromBn(await manager.getRiskyToStablePrice(), stableDecimals)
      ).to.be.equal("1");
    });
    /**
     * @notice Checks fetching both prices at a one-to-one exchange rate
     */
    it("correct one-to-one prices both ways", async function () {
      aggregatorV3.setLatestAnswer(
        parseWei("1", await aggregatorV3.decimals()).raw
      );
      let [stableToRiskyPrice, riskyToStablePrice] = await manager.getPrice();
      expect(fromBn(stableToRiskyPrice, riskyDecimals)).to.be.equal("1");
      expect(fromBn(riskyToStablePrice, stableDecimals)).to.be.equal("1");
    });
    /**
     * @notice Checks that for a unit of stable asset priced as two units
     * of risky asset, we obtain 2 risky in return
     * @dev the oracle price is manually changed
     */
    it("correct one-to-two stable to risky price", async function () {
      aggregatorV3.setLatestAnswer(
        parseWei("2", await aggregatorV3.decimals()).raw
      );
      expect(
        fromBn(await manager.getStableToRiskyPrice(), riskyDecimals)
      ).to.be.equal("2");
    });
    /**
     * @notice Checks that for a unit of risky asset priced as two units
     * of stable asset, we obtain 0.5 stable in return
     * @dev the oracle price is manually changed
     */
    it("correct one-to-two risky to stable price", async function () {
      aggregatorV3.setLatestAnswer(
        parseWei("2", await aggregatorV3.decimals()).raw
      );
      expect(
        fromBn(await manager.getRiskyToStablePrice(), stableDecimals)
      ).to.be.equal("0.5");
    });
    /**
     * @notice Checks fetching both prices at a one-to-two exchange rate
     */
    it("correct one-to-two prices both ways", async function () {
      aggregatorV3.setLatestAnswer(
        parseWei("2", await aggregatorV3.decimals()).raw
      );
      let [stableToRiskyPrice, riskyToStablePrice] = await manager.getPrice();
      expect(fromBn(stableToRiskyPrice, riskyDecimals)).to.be.equal("2");
      expect(fromBn(riskyToStablePrice, stableDecimals)).to.be.equal("0.5");
    });
    /**
     * @notice Checks price conversion works when assets have decimals=18
     * and oracle has decimals=12
     */
    it("correct stable to risky price with oracle decimals = 12", async function () {
      aggregatorV3.setLatestAnswer(
        parseWei("1", await aggregatorV3.decimals()).raw
      );
      aggregatorV3.setDecimals(12);
      expect(
        fromBn(await manager.getStableToRiskyPrice(), riskyDecimals)
      ).to.be.equal("1");
    });
    /**
     * @notice Checks fetching both prices with oracle decimals = 12
     */
    it("correct prices both ways with oracle decimals = 12", async function () {
      aggregatorV3.setLatestAnswer(
        parseWei("1", await aggregatorV3.decimals()).raw
      );
      aggregatorV3.setDecimals(12);
      let [stableToRiskyPrice, riskyToStablePrice] = await manager.getPrice();
      expect(fromBn(stableToRiskyPrice, riskyDecimals)).to.be.equal("1");
      expect(fromBn(riskyToStablePrice, stableDecimals)).to.be.equal("1");
    });
  });
  describe("vault management", function () {
    /**
     * @notice Checks getNextStrikePrice multiplies spot price
     * from oracle by the multiplier
     */
    it("correctly get next strike price - default", async function () {
      let spotPrice = await manager.getRiskyToStablePrice();
      let strikePrice = await manager.getNextStrikePrice(
        2000,
        8000,
        604800,
        stableDecimals,
      );
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.greaterThan(
        parseFloat(fromBn(spotPrice, stableDecimals))
      );
      // Hardcoded answer from previous run -- should not change
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.closeTo(1.10443209144177454, 1e-6);
    });
    it("correctly get next strike price - change delta", async function () {
      let spotPrice = await manager.getRiskyToStablePrice();
      let strikePrice = await manager.getNextStrikePrice(
        1000,
        8000,
        604800,
        stableDecimals,
      );
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.greaterThan(
        parseFloat(fromBn(spotPrice, stableDecimals))
      );
      // Hardcoded answer from previous run -- should not change
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.closeTo(1.159604176436641313, 1e-6);
    });
    it("correctly get next strike price - check delta direction", async function () {
      let strikePrice1 = await manager.getNextStrikePrice(
        1000,
        8000,
        604800,
        stableDecimals,
      );
      let strikePrice2 = await manager.getNextStrikePrice(
        1500,
        8000,
        604800,
        stableDecimals,
      );
      // Higher delta = lower next strike price
      expect(
        parseFloat(fromBn(strikePrice1, stableDecimals))
      ).to.be.greaterThan(
        parseFloat(fromBn(strikePrice2, stableDecimals))
      );
    });
    it("correctly get next strike price - check different tau", async function () {
      let spotPrice = await manager.getRiskyToStablePrice();
      let strikePrice = await manager.getNextStrikePrice(
        1000,
        8000,
        86400,
        stableDecimals,
      );
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.greaterThan(
        parseFloat(fromBn(spotPrice, stableDecimals))
      );
      // Hardcoded answer from previous run -- should not change
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.closeTo(1.0560405696252742, 1e-6);
    });
    it("correctly get next strike price - check tau direction", async function () {
      let strikePrice1 = await manager.getNextStrikePrice(
        1000,
        8000,
        86400,
        stableDecimals,
      );
      let strikePrice2 = await manager.getNextStrikePrice(
        1000,
        8000,
        604800,
        stableDecimals,
      );
      // Higher tau = higher next strike price
      expect(
        parseFloat(fromBn(strikePrice1, stableDecimals))
      ).to.be.lessThan(
        parseFloat(fromBn(strikePrice2, stableDecimals))
      );
    });
    it("correctly get next strike price - check different sigma", async function () {
      let spotPrice = await manager.getRiskyToStablePrice();
      let strikePrice = await manager.getNextStrikePrice(
        1000,
        1000,
        604800,
        stableDecimals,
      );
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.greaterThan(
        parseFloat(fromBn(spotPrice, stableDecimals))
      );
      // Hardcoded answer from previous run -- should not change
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.closeTo(1.0179991190380546, 1e-6);
    });
    it("correctly get next strike price - check sigma direction", async function () {
      let strikePrice1 = await manager.getNextStrikePrice(
        1000,
        8000,
        604800,
        stableDecimals,
      );
      let strikePrice2 = await manager.getNextStrikePrice(
        1000,
        1000,
        604800,
        stableDecimals,
      );
      // Higher sigma = higher next strike price
      expect(
        parseFloat(fromBn(strikePrice1, stableDecimals))
      ).to.be.greaterThan(
        parseFloat(fromBn(strikePrice2, stableDecimals))
      );
    });
    /**
     * @notice Checks getNextStrikePrice works with a different
     * initial non-unit price
     */
    it("correctly get next strike price with spot = pi", async function () {
      aggregatorV3.setLatestAnswer(
        parseWei("3.14", await aggregatorV3.decimals()).raw
      );
      let spotPrice = await manager.getRiskyToStablePrice();
      let strikePrice = await manager.getNextStrikePrice(
        2000,
        8000,
        604800,
        stableDecimals,
      );
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.greaterThan(
        parseFloat(fromBn(spotPrice, stableDecimals))
      );
      // Hardcoded answer from previous run -- should not change
      expect(
        parseFloat(fromBn(strikePrice, stableDecimals))
      ).to.be.closeTo(0.3517299654273167, 1e-6);
    });
    /**
     * @notice Checks fetching the volatility for next round
     * @dev This is currently hardcoded to return 0.8
     */
    it("correctly get next sigma", async function () {
      expect(fromBn(await manager.getNextSigma(), 4)).to.be.equal("0.8");
    });
    /**
     * @notice Checks fetching the gamma for next round
     * @dev This is currently hardcoded to return 0.95
     */
    it("correctly get next gamma", async function () {
      expect(fromBn(await manager.getNextGamma(), 4)).to.be.equal("0.95");
    });
    /**
     * @notice Check that invalid strike multipliers are blocked
     */
    it("blocks strike multiplier < 100", async function () {
      try {
        await manager.setStrikeMultiplier(90);
        expect(false); // must fail
      } catch {
        expect(true);
      }
    });
    /**
     * @notice Checks getRiskyPerLp logic with a variety of inputs
     * for strike, sigma, and maturity
     */
    it("correct computation of R1", async function () {
      // The spot is at price 1
      var strikes = [1.001, 1.01, 1.1, 0.999, 0.99, 0.9];
      var sigmas = [0.1, 0.3, 0.5, 0.7, 0.9];
      var tauInSeconds = [
        3600, // one hour
        86400, // one day
        604800, // one week
      ];

      let strike: string;
      let sigma: string;
      let r1: string;

      for (var i = 0; i < strikes.length; i++) {
        for (var j = 0; j < sigmas.length; j++) {
          for (var k = 0; k < tauInSeconds.length; k++) {
            strike = toBn(strikes[i].toString(), stableDecimals).toString();
            sigma = toBn(sigmas[j].toString(), 4).toString();
            r1 = fromBn(
              await manager.getRiskyPerLp(
                toBn("1", stableDecimals).toString(),
                strike,
                sigma,
                tauInSeconds[k],
                riskyDecimals,
                stableDecimals
              ),
              riskyDecimals
            );

            let tau = tauInSeconds[k] / 31536000;
            let top = Math.log(1 / strikes[i]) + (tau * sigmas[j] ** 2) / 2;
            let bot = sigmas[j] * Math.sqrt(tau);
            let d1 = top / bot;
            let r2 = 1 - normalCDF(d1, 0, 1);
            r2 = Math.max(Math.min(r2, 0.99), 0.01);

            /// @dev: 0.01 is a generous margin for error
            expect(parseFloat(r1)).to.be.closeTo(r2, 0.01);
          }
        }
      }
    });
  });
});
