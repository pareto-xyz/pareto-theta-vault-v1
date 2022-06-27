import hre, { ethers } from "hardhat";
import { Contract } from "ethers";
import { parseWei } from "web3-units";
import expect from "./shared/expect";

let manager: Contract;

describe("Manager contract", function() {
  beforeEach(async function() {
    const [deployer] = await hre.ethers.getSigners();

    // Create ERC20 for risky and stable tokens
    const MockERC20 = await ethers.getContractFactory("MockERC20", deployer);
    let risky = await MockERC20.deploy();
    let stable = await MockERC20.deploy();

    // Create and deploy Mock Chainlink protocol
    const AggregatorV3 = 
    await ethers.getContractFactory("MockAggregatorV3", deployer);
    const aggregatorV3 = await AggregatorV3.deploy();
    aggregatorV3.setLatestAnswer(1);  // initialize price as 1

    // Award deployer some tokens
    await risky.mint(deployer.address, parseWei("1000000").raw);
    await stable.mint(deployer.address, parseWei("1000000").raw);

    this.contracts = {
      risky: risky,
      stable: stable,
      aggregatorV3: aggregatorV3,
    };
    this.wallets = {deployer};

    // Load the manager
    const ParetoManager = await hre.ethers.getContractFactory("ParetoManager");
    manager = await ParetoManager.deploy(
      150,
      this.contracts.risky.address,
      this.contracts.stable.address,
      this.contracts.aggregatorV3.address,
      false
    );
  });
  describe('asset getters', function() {
    it('correct default risky', async function() {
      expect(
        await manager.risky()
      ).to.be.equal(this.contracts.risky.address);
    });
    it('correct default stable', async function() {
      expect(
        await manager.stable()
      ).to.be.equal(this.contracts.stable.address);
    });
    it('correct default strike multiplier', async function() {
      expect(
        await manager.strikeMultiplier()
      ).to.be.equal(150);  // by initialization
    });
  });
});