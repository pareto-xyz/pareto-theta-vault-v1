import hre, { ethers } from "hardhat";
import { Contract } from "ethers";
import { parseWei } from "web3-units";
import expect from "./shared/expect";
import { fromBn } from 'evm-bn';

let manager: Contract;
let risky: Contract;
let stable: Contract;
let aggregatorV3: Contract;
let riskyDecimals: number;
let stableDecimals: number;
let oracleDecimals: number;

describe("Manager contract", function() {
  beforeEach(async function() {
    const [deployer] = await hre.ethers.getSigners();

    // Create ERC20 for risky and stable tokens
    const MockERC20 = await ethers.getContractFactory("MockERC20", deployer);
    risky = await MockERC20.deploy();
    stable = await MockERC20.deploy();

    // Create and deploy Mock Chainlink protocol
    const AggregatorV3 = 
    await ethers.getContractFactory("MockAggregatorV3", deployer);
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
      150,
      risky.address,
      stable.address,
      aggregatorV3.address,
      false
    );
  });
  describe('asset getters', function() {
    /**
     * @notice Checks that the manager's stored risky asset is correct
     */
    it('correct default risky', async function() {
      expect(
        await manager.risky()
      ).to.be.equal(risky.address);
    });
    /**
     * @notice Checks that the manager's stored stable asset is correct
     */
    it('correct default stable', async function() {
      expect(
        await manager.stable()
      ).to.be.equal(stable.address);
    });
    /**
     * @notice Checks that the manager's stored strike multiplier is correct
     */
    it('correct default strike multiplier', async function() {
      expect(
        await manager.strikeMultiplier()
      ).to.be.equal(150);  // by initialization
    });
  });
  describe('function getters', function() {
    /**
     * @notice Checks that the manager's oracle decimals is expected
     */
    it('correct oracle decimals', async function() {
      let oracleDecimals = await aggregatorV3.decimals();
      expect(
        await manager.getOracleDecimals()
      ).to.be.equal(oracleDecimals);
    });
    /**
     * @notice Checks that for a unit of stable asset priced as a unit 
     * of risky asset, we obtain one risky in return
     */
    it('correct one-to-one stable to risky price', async function() {
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
    it('correct one-to-one risky to stable price', async function() {
      // Set oracle price to be 1 risky for 1 stable
      aggregatorV3.setLatestAnswer(
        parseWei("1", await aggregatorV3.decimals()).raw
      );
      expect(
        fromBn(await manager.getRiskyToStablePrice(), stableDecimals)
      ).to.be.equal("1");
    });
    /**
     * @notice Checks that for a unit of stable asset priced as two units 
     * of risky asset, we obtain 2 risky in return
     * @dev the oracle price is manually changed
     */
    it('correct one-to-two stable to risky price', async function() {
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
    it('correct one-to-two risky to stable price', async function() {
      aggregatorV3.setLatestAnswer(
        parseWei("2", await aggregatorV3.decimals()).raw
      );
      expect(
        fromBn(await manager.getRiskyToStablePrice(), stableDecimals)
      ).to.be.equal("0.5");
    });
    /**
     * @notice Checks price conversion works when assets have decimals=18
     * and oracle has decimals=12
     */
    it('correct stable to risky price with oracle decimals = 12', async function() {
      aggregatorV3.setLatestAnswer(
        parseWei("1", await aggregatorV3.decimals()).raw
      );
      aggregatorV3.setDecimals(12);
      expect(
        fromBn(await manager.getStableToRiskyPrice(), riskyDecimals)
      ).to.be.equal("1");
    });
  });
  describe('vault management', function() {
  });
});