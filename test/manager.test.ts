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
    oracleDecimals = await aggregatorV3.decimals();

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
    it('correct default risky', async function() {
      expect(
        await manager.risky()
      ).to.be.equal(risky.address);
    });
    it('correct default stable', async function() {
      expect(
        await manager.stable()
      ).to.be.equal(stable.address);
    });
    it('correct default strike multiplier', async function() {
      expect(
        await manager.strikeMultiplier()
      ).to.be.equal(150);  // by initialization
    });
  });
  describe('function getters', function() {
    it('correct oracle decimals', async function() {
      expect(
        await manager.getOracleDecimals()
      ).to.be.equal(oracleDecimals);
    });
    it('correct one-to-one stable to risky price', async function() {
      // Set oracle price to be 1 stable for 1 risky
      aggregatorV3.setLatestAnswer(parseWei("1", oracleDecimals).raw);
      let expected = (oracleDecimals - riskyDecimals) > 0
        ? parseWei("1", oracleDecimals - riskyDecimals).raw
        : "1";
      expect(
        fromBn(await manager.getStableToRiskyPrice(), riskyDecimals)
      ).to.be.equal(expected);
    });
    it('correct one-to-one risky to stable price', async function() {
      // Set oracle price to be 1 risky for 1 stable
      aggregatorV3.setLatestAnswer(parseWei("1", oracleDecimals).raw);
      let expected = (oracleDecimals - stableDecimals) > 0
        ? parseWei("1", oracleDecimals - stableDecimals).raw
        : "1";
      expect(
        fromBn(await manager.getRiskyToStablePrice(), stableDecimals)
      ).to.be.equal(expected);
    });
  });
  describe('vault management', function() {
  });
});