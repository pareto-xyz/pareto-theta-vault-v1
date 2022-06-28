import hre from "hardhat";
import { constants, Contract } from "ethers";
import { parseWei } from "web3-units";
import { fromBn, toBn } from "evm-bn";
import { runTest } from "./shared/fixture";
import expect from "./shared/expect";

let vault: Contract;
let riskyDecimals: number;
let stableDecimals: number;

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
    riskyDecimals = await this.contracts.risky.decimals();
    stableDecimals = await this.contracts.stable.decimals();
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
    it("correct default uniswap fee", async function() {
      expect(
        fromBn((await vault.uniswapParams()).poolFee, 6)
      ).to.be.equal("0.003");
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
      let expectedFee = 20 / 52.142857;
      /// @dev fees are in 4 decimal points
      expect(
        parseFloat(fromBn(await vault.managementFee(), 4))
      ).to.be.closeTo(expectedFee, 0.001);
    });
    it("correct default performance fee", async function() {
      /// @dev fees are in 4 decimal points
      expect(
        fromBn(await vault.performanceFee(), 4)
      ).to.be.equal("2");
    });
    it("correct default round", async function() {
      expect(
        (await vault.vaultState()).round
      ).to.be.equal(1);
    });
    it("check share price in risky for round 1 is 0", async function() {
      expect(
        fromBn(await vault.roundSharePriceInRisky(1))
      ).to.be.equal("0");
    });
    it("check share price in stable for round 1 is 0", async function() {
      expect(
        fromBn(await vault.roundSharePriceInRisky(1))
      ).to.be.equal("0");
    });
    /**
     * @notice Checks that all the parameters inside vaultState are 
     *  properly initialized
     */
    it("correct default vault state", async function() {
      let vaultState = await vault.vaultState();
      expect(
        fromBn(vaultState.lockedRisky, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lockedStable, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lastLockedRisky, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lastLockedStable, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.pendingRisky, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lastQueuedWithdrawRisky, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lastQueuedWithdrawStable, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lastQueuedWithdrawStable, 1)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.currQueuedWithdrawShares, 1)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.totalQueuedWithdrawShares, 1)
      ).to.be.equal("0");
    });
    /**
     * @notice Checks that all the parameters in pool state are
     *  properly initialized
     */
    it("correct default pool state", async function() {
      let poolState = await vault.poolState();
      expect(parseFloat(poolState.currPoolId)).to.be.equal(0);
      expect(parseFloat(poolState.nextPoolId)).to.be.equal(0);
      expect(poolState.nextPoolReadyAt).to.be.equal(0);
      expect(
        fromBn(poolState.currLiquidity, 18)
      ).to.be.equal("0");
      // Check the parameters in the current pool parameters
      expect(
        fromBn(poolState.currPoolParams.strike, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(poolState.currPoolParams.sigma, 4)
      ).to.be.equal("0");
      expect(
        fromBn(poolState.currPoolParams.gamma, 4)
      ).to.be.equal("0");
      expect(
        poolState.currPoolParams.maturity,
      ).to.be.equal(0);
      expect(
        fromBn(poolState.currPoolParams.riskyPerLp, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(poolState.currPoolParams.delLiquidity, 18)
      ).to.be.equal("0");
      // Check the parameters in the next pool parameters
      expect(
        fromBn(poolState.nextPoolParams.strike, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(poolState.nextPoolParams.sigma, 4)
      ).to.be.equal("0");
      expect(
        fromBn(poolState.nextPoolParams.gamma, 4)
      ).to.be.equal("0");
      expect(
        poolState.nextPoolParams.maturity,
      ).to.be.equal(0);
      expect(
        fromBn(poolState.nextPoolParams.riskyPerLp, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(poolState.nextPoolParams.delLiquidity, 18)
      ).to.be.equal("0");
    });
    /**
     * @notice Checks that all the parameters in manager state are
     *  properly initialized
     */
    it("correct default manager state", async function() {
      let managerState = await vault.managerState();
      expect(
        fromBn(managerState.manualStrike, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(managerState.manualVolatility, 4)
      ).to.be.equal("0");
      // Volatility (sigma) must be in [0, 1]
      expect(
        parseFloat(fromBn(managerState.manualVolatility, 4))
      ).to.be.greaterThanOrEqual(0);
      expect(
        parseFloat(fromBn(managerState.manualVolatility, 4))
      ).to.be.lessThanOrEqual(1);
      // Gamma (1 - fee) must be in [0, 1]
      expect(
        fromBn(managerState.manualGamma, 4)
      ).to.be.equal("0");
      expect(
        parseFloat(fromBn(managerState.manualGamma, 4))
      ).to.be.greaterThanOrEqual(0);
      expect(
        parseFloat(fromBn(managerState.manualGamma, 4))
      ).to.be.lessThanOrEqual(1);
      // Rounds are initialized to zero
      expect(managerState.manualStrikeRound).to.be.equal(0);
      expect(managerState.manualVolatilityRound).to.be.equal(0);
      expect(managerState.manualGammaRound).to.be.equal(0);
    });
    /**
     * @notice Check contract has zero risky and zero stable tokens
     *  Check contract has zero Pareto (receipt tokens)
     */
    it("check initial vault balance", async function() {
      expect(
        fromBn(await this.contracts.risky.balanceOf(vault.address), riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(await this.contracts.stable.balanceOf(vault.address), stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(await vault.balanceOf(vault.address), stableDecimals)
      ).to.be.equal("0");
    });
  });
  describe("check keeper functions", function() {
    it("correctly set keeper", async function() {
    });
  });
});