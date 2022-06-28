import hre from "hardhat";
import { constants, Contract } from "ethers";
import { parseWei } from "web3-units";
import { fromBn, toBn } from "evm-bn";
import { runTest } from "./shared/fixture";
import expect from "./shared/expect";

let vault: Contract;

/**
 * @notice `runTest` is a wrapper function that sets up the on-chain
 * dependencies (or mock contracts of) prior to tests written below
 * @dev see test/shared/fixture.ts
 */
runTest("vault", function() {
  beforeEach(async function() {
    const ParetoVault = await hre.ethers.getContractFactory("ParetoVault");
    vault = await ParetoVault.deploy(
      this.wallets.keeper.address,
      this.wallets.feeRecipient.address,
      this.contracts.vaultManager.address,
      this.contracts.primitiveManager.address,
      this.contracts.primitiveEngine.address,
      this.contracts.swapRouter.address,
      this.contracts.risky.address,
      this.contracts.stable.address,
      200000,
      20000,
    );
  });
  /**
   * @notice Checks that the public getter functions return default 
   *  values as expected
   */
  describe("asset getters", function() {
    it("correct default keeper address", async function() {
      expect(
        await vault.keeper()
      ).to.be.equal(this.wallets.keeper.address);
    });
    it("correct default fee receipient address", async function() {
      expect(
        await vault.feeRecipient()
      ).to.be.equal(this.wallets.feeRecipient.address);
    });
    it("correct default vault manager address", async function() {
      expect(
        await vault.vaultManager()
      ).to.be.equal(this.contracts.vaultManager.address);
    });
    it("correct default primitive manager address", async function() {
      expect(
        (await vault.primitiveParams()).manager
      ).to.be.equal(this.contracts.primitiveManager.address);
    });
    it("correct default primitive engine address", async function() {
      expect(
        (await vault.primitiveParams()).engine
      ).to.be.equal(this.contracts.primitiveEngine.address);
    });
    it("correct default uniswap router address", async function() {
      expect(
        (await vault.uniswapParams()).router
      ).to.be.equal(this.contracts.swapRouter.address);
    });
    it("correct default risky address", async function() {
      expect(
        await vault.risky()
      ).to.be.equal(this.contracts.risky.address);
    });
    it("correct default stable address", async function() {
      expect(
        await vault.stable()
      ).to.be.equal(this.contracts.stable.address);
    });
    it("correct default management fee", async function() {
      /// @dev fees are in 4 decimal points
      expect(
        fromBn(await vault.managementFee(), 4)
      ).to.be.equal("0.3835");
    });
    it("correct default performance fee", async function() {
      /// @dev fees are in 4 decimal points
      expect(
        fromBn(await vault.performanceFee(), 4)
      ).to.be.equal("2");
    });
  });
  describe("check keeper functions", function() {
    it("correctly set keeper", async function() {
    });
  });
});