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
runTest("ParetoVault", function () {
  beforeEach(async function () {
    const ParetoVault = await hre.ethers.getContractFactory("ParetoVault");
    vault = await ParetoVault.deploy(
      this.wallets.keeper.address,
      this.wallets.feeRecipient.address,
      this.contracts.vaultManager.address,
      this.contracts.primitiveManager.address,
      this.contracts.primitiveEngine.address,
      this.contracts.primitiveFactory.address,
      this.contracts.swapRouter.address,
      this.contracts.risky.address,
      this.contracts.stable.address,
      200000,
      20000
    );
    await vault.initRounds(10);
    riskyDecimals = await this.contracts.risky.decimals();
    stableDecimals = await this.contracts.stable.decimals();

    // Grant vault permission from Alice
    await this.contracts.risky
      .connect(this.wallets.alice)
      .increaseAllowance(vault.address, constants.MaxUint256);
    await this.contracts.stable
      .connect(this.wallets.alice)
      .increaseAllowance(vault.address, constants.MaxUint256);
  });
  /**
   * @notice Checks that the public getter functions return default
   *  values as expected
   */
  describe("asset getters", function () {
    it("correct default keeper address", async function () {
      expect(await vault.keeper()).to.be.equal(this.wallets.keeper.address);
    });
    it("correct default fee receipient address", async function () {
      expect(await vault.feeRecipient()).to.be.equal(
        this.wallets.feeRecipient.address
      );
    });
    it("correct default vault manager address", async function () {
      expect(await vault.vaultManager()).to.be.equal(
        this.contracts.vaultManager.address
      );
    });
    it("correct default primitive manager address", async function () {
      expect((await vault.primitiveParams()).manager).to.be.equal(
        this.contracts.primitiveManager.address
      );
    });
    it("correct default primitive engine address", async function () {
      expect((await vault.primitiveParams()).engine).to.be.equal(
        this.contracts.primitiveEngine.address
      );
    });
    it("correct default uniswap router address", async function () {
      expect((await vault.uniswapParams()).router).to.be.equal(
        this.contracts.swapRouter.address
      );
    });
    it("correct default uniswap fee", async function () {
      expect(fromBn((await vault.uniswapParams()).poolFee, 6)).to.be.equal(
        "0.003"
      );
    });
    it("correct default risky address", async function () {
      let tokenParams = await vault.tokenParams();
      expect(tokenParams.risky).to.be.equal(this.contracts.risky.address);
    });
    it("correct default stable address", async function () {
      let tokenParams = await vault.tokenParams();
      expect(tokenParams.stable).to.be.equal(this.contracts.stable.address);
    });
    it("correct default management fee", async function () {
      let expectedFee = 20 / 52.142857;
      /// @dev fees are in 4 decimal points
      expect(parseFloat(fromBn(await vault.managementFee(), 4))).to.be.closeTo(
        expectedFee,
        0.001
      );
    });
    it("correct default performance fee", async function () {
      /// @dev fees are in 4 decimal points
      expect(fromBn(await vault.performanceFee(), 4)).to.be.equal("2");
    });
    it("correct default round", async function () {
      expect((await vault.vaultState()).round).to.be.equal(1);
    });
    it("check share price in risky at start", async function () {
      expect(await vault.roundSharePriceInRisky(1)).to.be.equal(1);
    });
    it("check share price in stable at start", async function () {
      expect(await vault.roundSharePriceInStable(1)).to.be.equal(1);
    });
    /**
     * @notice Checks that all the parameters inside vaultState are
     *  properly initialized
     */
    it("correct default vault state", async function () {
      let vaultState = await vault.vaultState();
      expect(fromBn(vaultState.lockedRisky, riskyDecimals)).to.be.equal("0");
      expect(fromBn(vaultState.lockedStable, stableDecimals)).to.be.equal("0");
      expect(fromBn(vaultState.lastLockedRisky, riskyDecimals)).to.be.equal(
        "0"
      );
      expect(fromBn(vaultState.lastLockedStable, stableDecimals)).to.be.equal(
        "0"
      );
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("0");
      expect(
        fromBn(vaultState.lastQueuedWithdrawRisky, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lastQueuedWithdrawStable, stableDecimals)
      ).to.be.equal("0");
      expect(fromBn(vaultState.lastQueuedWithdrawStable, 1)).to.be.equal("0");
      expect(fromBn(vaultState.currQueuedWithdrawShares, 1)).to.be.equal("0");
      expect(fromBn(vaultState.totalQueuedWithdrawShares, 1)).to.be.equal("0");
    });
    /**
     * @notice Checks that all the parameters in pool state are
     *  properly initialized
     */
    it("correct default pool state", async function () {
      let poolState = await vault.poolState();
      expect(parseFloat(poolState.currPoolId)).to.be.equal(0);
      expect(parseFloat(poolState.nextPoolId)).to.be.equal(0);
      expect(poolState.nextPoolReadyAt).to.be.equal(0);
      expect(fromBn(poolState.currLiquidity, 18)).to.be.equal("0");
      // Check the parameters in the current pool parameters
      expect(
        fromBn(poolState.currPoolParams.strike, stableDecimals)
      ).to.be.equal("0");
      expect(fromBn(poolState.currPoolParams.sigma, 4)).to.be.equal("0");
      expect(fromBn(poolState.currPoolParams.gamma, 4)).to.be.equal("0");
      expect(poolState.currPoolParams.maturity).to.be.equal(0);
      expect(
        fromBn(poolState.currPoolParams.riskyPerLp, riskyDecimals)
      ).to.be.equal("0");
      expect(fromBn(poolState.currPoolParams.delLiquidity, 18)).to.be.equal(
        "0"
      );
      // Check the parameters in the next pool parameters
      expect(
        fromBn(poolState.nextPoolParams.strike, stableDecimals)
      ).to.be.equal("0");
      expect(fromBn(poolState.nextPoolParams.sigma, 4)).to.be.equal("0");
      expect(fromBn(poolState.nextPoolParams.gamma, 4)).to.be.equal("0");
      expect(poolState.nextPoolParams.maturity).to.be.equal(0);
      expect(
        fromBn(poolState.nextPoolParams.riskyPerLp, riskyDecimals)
      ).to.be.equal("0");
      expect(fromBn(poolState.nextPoolParams.delLiquidity, 18)).to.be.equal(
        "0"
      );
    });
    /**
     * @notice Checks that all the parameters in manager state are
     *  properly initialized
     */
    it("correct default manager state", async function () {
      let managerState = await vault.managerState();
      expect(fromBn(managerState.manualStrike, stableDecimals)).to.be.equal(
        "0"
      );
      expect(fromBn(managerState.manualVolatility, 4)).to.be.equal("0");
      // Volatility (sigma) must be in [0, 1]
      expect(
        parseFloat(fromBn(managerState.manualVolatility, 4))
      ).to.be.greaterThanOrEqual(0);
      expect(
        parseFloat(fromBn(managerState.manualVolatility, 4))
      ).to.be.lessThanOrEqual(1);
      // Gamma (1 - fee) must be in [0, 1]
      expect(fromBn(managerState.manualGamma, 4)).to.be.equal("0");
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
    it("check initial vault balance", async function () {
      expect(
        fromBn(
          await this.contracts.risky.balanceOf(vault.address),
          riskyDecimals
        )
      ).to.be.equal("0");
      expect(
        fromBn(
          await this.contracts.stable.balanceOf(vault.address),
          stableDecimals
        )
      ).to.be.equal("0");
      expect(
        fromBn(await vault.balanceOf(vault.address), stableDecimals)
      ).to.be.equal("0");
    });
  });
  /**
   * @notice Tests owner functionalities in setter functions
   */
  describe("check owner functions", function () {
    it("correctly set keeper", async function () {
      expect(await vault.keeper()).to.be.equal(this.wallets.keeper.address);
      await vault.setKeeper(this.wallets.alice.address);
      expect(await vault.keeper()).to.be.equal(this.wallets.alice.address);
    });
    it("correctly set fee recipient", async function () {
      expect(await vault.feeRecipient()).to.be.equal(
        this.wallets.feeRecipient.address
      );
      await vault.setFeeRecipient(this.wallets.alice.address);
      expect(await vault.feeRecipient()).to.be.equal(
        this.wallets.alice.address
      );
    });
    it("correctly set management fee", async function () {
      let expectedFee = 30 / 52.142857;
      await vault.setManagementFee(300000);
      expect(parseFloat(fromBn(await vault.managementFee(), 4))).to.be.closeTo(
        expectedFee,
        0.001
      );
    });
    it("correctly set performance fee", async function () {
      await vault.setPerformanceFee(30000);
      expect(fromBn(await vault.performanceFee(), 4)).to.be.equal("3");
    });
    it("correctly set vault manager", async function () {
      await vault.setVaultManager(this.wallets.deployer.address);
      expect(await vault.vaultManager()).to.be.equal(
        this.wallets.deployer.address
      );
    });
  });
  /**
   * @notice Tests keeper functionalities in setter functions
   */
  describe("check keeper functions", function () {
    it("correctly set uniswap pool fee", async function () {
      await vault.connect(this.wallets.keeper).setUniswapPoolFee(5000);
      expect(fromBn((await vault.uniswapParams()).poolFee, 6)).to.be.equal(
        "0.005"
      );
    });
    it("correctly set strike price", async function () {
      await vault
        .connect(this.wallets.keeper)
        .setStrikePrice(toBn("2", stableDecimals));
      expect(
        fromBn((await vault.managerState()).manualStrike, stableDecimals)
      ).to.be.equal("2");
      expect((await vault.managerState()).manualStrikeRound).to.be.equal(1);
    });
    it("correctly set sigma", async function () {
      await vault.connect(this.wallets.keeper).setVolatility(toBn("0.8", 4));
      expect(
        fromBn((await vault.managerState()).manualVolatility, 4)
      ).to.be.equal("0.8");
      expect((await vault.managerState()).manualVolatilityRound).to.be.equal(1);
    });
    it("correctly set gamma", async function () {
      await vault.connect(this.wallets.keeper).setGamma(toBn("0.95", 4));
      expect(fromBn((await vault.managerState()).manualGamma, 4)).to.be.equal(
        "0.95"
      );
      expect((await vault.managerState()).manualGammaRound).to.be.equal(1);
    });
  });
  /**
   * @notice Test depositing into vault
   * @dev This does not test rollover nor pool creation
   */
  describe("check depositing into vault", function () {
    it("correct account balances post deposit", async function () {
      let aliceStart = parseFloat(
        fromBn(
          await this.contracts.risky.balanceOf(this.wallets.alice.address),
          riskyDecimals
        )
      );
      await vault.connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));
      // The vault should gain 1000
      expect(fromBn(await vault.totalRisky(), riskyDecimals)).to.be.equal(
        "1000"
      );

      let aliceEnd = parseFloat(
        fromBn(
          await this.contracts.risky.balanceOf(this.wallets.alice.address),
          riskyDecimals
        )
      );
      // Alice should lose that amount
      expect(aliceStart - aliceEnd).to.be.equal(1000);
    });
    it("correct change to pending risky post single deposit", async function () {
      let vaultState: any;
      vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("0");
      // Perform the deposit
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));
      vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal(
        "1000"
      );
    });
    it("correct receipt post single deposit", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));
      var receipt = await vault.depositReceipts(this.wallets.alice.address);
      expect(receipt.round).to.be.equal(1);
      expect(fromBn(receipt.riskyToDeposit, riskyDecimals)).to.be.equal("1000");
      expect(fromBn(receipt.ownedShares, 1)).to.be.equal("0");
    });
    it("correct account balances post double deposit", async function () {
      let aliceStart = parseFloat(
        fromBn(
          await this.contracts.risky.balanceOf(this.wallets.alice.address),
          riskyDecimals
        )
      );
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("500", riskyDecimals));
      let aliceEnd = parseFloat(
        fromBn(
          await this.contracts.risky.balanceOf(this.wallets.alice.address),
          riskyDecimals
        )
      );
      // Alice should lose that amount
      expect(aliceStart - aliceEnd).to.be.equal(1500);
    });
    it("correct change to pending risky post double deposit", async function () {
      let vaultState: any;
      vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("0");
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("500", riskyDecimals));
      vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal(
        "1500"
      );
    });
    it("correct receipt post double deposit", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("500", riskyDecimals));
      var receipt = await vault.depositReceipts(this.wallets.alice.address);
      expect(receipt.round).to.be.equal(1);
      expect(fromBn(receipt.riskyToDeposit, riskyDecimals)).to.be.equal("1500");
      expect(fromBn(receipt.ownedShares, 1)).to.be.equal("0");
    });
  });
  /**
   * @notice Test vault deployment
   * @dev This will call `_prepareNextPool` as well as `_deployPool`
   */
  describe("check vault deployment", function () {
    it("test", async function () {
      console.log("hi");
      await vault.connect(this.wallets.keeper).deployVault();
    });
  });
  /**
   * @notice Test public getter functions
   */
  describe("check public getter functions", function () {
    it("correct default amount of total risky assets", async function () {
      expect(fromBn(await vault.totalRisky(), riskyDecimals)).to.be.equal("0");
    });
    it("correct default amount of total stable assets", async function () {
      expect(fromBn(await vault.totalStable(), stableDecimals)).to.be.equal(
        "0"
      );
    });
    it("correct non-zero amount of total risky assets", async function () {
      await this.contracts.risky.mint(vault.address, parseWei("100000").raw);
      expect(fromBn(await vault.totalRisky(), riskyDecimals)).to.be.equal(
        "100000"
      );
    });
    it("correct non-zero amount of total stable assets", async function () {
      await this.contracts.stable.mint(vault.address, parseWei("100000").raw);
      expect(fromBn(await vault.totalStable(), stableDecimals)).to.be.equal(
        "100000"
      );
    });
  });
});
