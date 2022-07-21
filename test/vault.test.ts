import hre from "hardhat";
import { constants, Contract } from "ethers";
import { parseWei } from "web3-units";
import { fromBn, toBn } from "evm-bn";
import { BigNumber } from "@ethersproject/bignumber";
import { runTest } from "./shared/fixture";
import expect from "./shared/expect";
import {
  getVaultFees,
  getLockedAmounts,
  fromBnToFloat,
  getVaultBalance,
  getBestSwap,
} from "../scripts/utils/testUtils";

let vault: Contract;
let riskyDecimals: number;
let stableDecimals: number;
let shareDecimals: number;

/**
 * @notice `runTest` is a wrapper function that sets up the on-chain
 * dependencies (or mock contracts of) prior to tests written below
 * @dev see test/shared/fixture.ts
 */
runTest("ParetoVault", function () {
  beforeEach(async function () {
    const ParetoVault = await hre.ethers.getContractFactory("ParetoVault");
    vault = await ParetoVault.connect(this.wallets.deployer).deploy(
      this.wallets.keeper.address,
      this.wallets.feeRecipient.address,
      this.contracts.vaultManager.address,
      this.contracts.primitiveManager.address,
      this.contracts.primitiveEngine.address,
      this.contracts.primitiveFactory.address,
      this.contracts.swapRouter.address,
      this.contracts.risky.address,
      this.contracts.stable.address,
      20000000, /// 20% performance fee
      2000000 /// 2% yearly management fee
    );

    // Owner should provide a bit of liquidity
    const deployFee = await vault.MIN_LIQUIDITY();
    await this.contracts.risky
      .connect(this.wallets.deployer)
      .increaseAllowance(vault.address, deployFee);
    await this.contracts.stable
      .connect(this.wallets.deployer)
      .increaseAllowance(vault.address, deployFee);
    await vault.connect(this.wallets.deployer).seedVault();

    // For tests, set an upper bound of 10 rounds to hot start
    await vault.initRounds(10);

    // Assign some global variables
    riskyDecimals = await this.contracts.risky.decimals();
    stableDecimals = await this.contracts.stable.decimals();
    shareDecimals = await vault.decimals();

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
    it("correct default fee recipient address", async function () {
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
        "0.005"
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
      expect(fromBnToFloat(await vault.managementFee(), 6)).to.be.closeTo(
        expectedFee,
        0.001
      );
    });
    it("correct default performance fee", async function () {
      /// @dev fees are in 4 decimal points
      expect(fromBn(await vault.performanceFee(), 6)).to.be.equal("2");
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
    it("check risky token address", async function () {
      expect(await vault.risky()).to.be.equal(this.contracts.risky.address);
    });
    it("check stable token address", async function () {
      expect(await vault.stable()).to.be.equal(this.contracts.stable.address);
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
        fromBn(BigNumber.from(100000), riskyDecimals).toString()
      );
      expect(fromBn(vaultState.lastLockedStable, stableDecimals)).to.be.equal(
        fromBn(BigNumber.from(100000), riskyDecimals).toString()
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
      expect(poolState.currPoolId == 0).to.be.equal(true);
      expect(poolState.nextPoolId == 0).to.be.equal(true);
      expect(poolState.nextPoolReadyAt).to.be.equal(0);
      expect(fromBn(poolState.currLiquidity, shareDecimals)).to.be.equal("0");
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
    });
    /**
     * @notice Checks that all the parameters in manager state are
     *  properly initialized
     */
    it("correct default manager state", async function () {
      let managerState = await vault.controller();
      expect(fromBn(managerState.strike, stableDecimals)).to.be.equal("0");
      expect(fromBn(managerState.sigma, 4)).to.be.equal("0");
      // Sigma must be in [0, 1]
      expect(fromBnToFloat(managerState.sigma, 4)).to.be.greaterThanOrEqual(0);
      expect(fromBnToFloat(managerState.sigma, 4)).to.be.lessThanOrEqual(1);
      // Gamma (1 - fee) must be in [0, 1]
      expect(fromBn(managerState.gamma, 4)).to.be.equal("0");
      expect(fromBnToFloat(managerState.gamma, 4)).to.be.greaterThanOrEqual(0);
      expect(fromBnToFloat(managerState.gamma, 4)).to.be.lessThanOrEqual(1);
      // Rounds are initialized to zero
      expect(managerState.strikeRound).to.be.equal(0);
      expect(managerState.sigmaRound).to.be.equal(0);
      expect(managerState.gammaRound).to.be.equal(0);
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
      ).to.be.equal(fromBn(BigNumber.from(100000), riskyDecimals).toString());
      expect(
        fromBn(
          await this.contracts.stable.balanceOf(vault.address),
          stableDecimals
        )
      ).to.be.equal(fromBn(BigNumber.from(100000), riskyDecimals).toString());
      expect(
        fromBn(await vault.balanceOf(vault.address), shareDecimals)
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
    it("check user cannot set keeper", async function () {
      try {
        await vault
          .connect(this.wallets.alice)
          .setKeeper(this.wallets.alice.address);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check current keeper cannot set keeper", async function () {
      try {
        await vault
          .connect(this.wallets.keeper)
          .setKeeper(this.wallets.alice.address);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check fee recipient cannot set keeper", async function () {
      try {
        await vault
          .connect(this.wallets.feeRecipient)
          .setKeeper(this.wallets.alice.address);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
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
    it("check user cannot set fee recipient", async function () {
      try {
        await vault
          .connect(this.wallets.alice)
          .setFeeRecipient(this.wallets.alice.address);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check keeper cannot set fee recipient", async function () {
      try {
        await vault
          .connect(this.wallets.keeper)
          .setFeeRecipient(this.wallets.alice.address);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check current fee recipient cannot set fee recipient", async function () {
      try {
        await vault
          .connect(this.wallets.feeRecipient)
          .setFeeRecipient(this.wallets.alice.address);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("correctly set management fee", async function () {
      let expectedFee = 30 / 52.142857;
      await vault.setManagementFee(300000);
      expect(fromBnToFloat(await vault.managementFee(), 4)).to.be.closeTo(
        expectedFee,
        0.001
      );
    });
    it("check user cannot set management fee", async function () {
      try {
        await vault.connect(this.wallets.alice).setManagementFee(300000);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check keeper cannot set management fee", async function () {
      try {
        await vault.connect(this.wallets.keeper).setManagementFee(300000);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check fee recipient cannot set management fee", async function () {
      try {
        await vault.connect(this.wallets.feeRecipient).setManagementFee(300000);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("correctly set performance fee", async function () {
      await vault.setPerformanceFee(30000);
      expect(fromBn(await vault.performanceFee(), 4)).to.be.equal("3");
    });
    it("check user cannot set performance fee", async function () {
      try {
        await vault.connect(this.wallets.alice).setPerformanceFee(300000);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check keeper cannot set performance fee", async function () {
      try {
        await vault.connect(this.wallets.keeper).setPerformanceFee(300000);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check fee recipient cannot set performance fee", async function () {
      try {
        await vault
          .connect(this.wallets.feeRecipient)
          .setPerformanceFee(300000);
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("correctly set vault manager", async function () {
      await vault.setVaultManager(this.wallets.deployer.address);
      expect(await vault.vaultManager()).to.be.equal(
        this.wallets.deployer.address
      );
    });
    it("correct default vault cap", async function () {
      let controller = await vault.controller();
      expect(controller.capRisky).to.be.equal(toBn("10", riskyDecimals));
    });
    it("correctly set vault cap", async function () {
      await vault.setCapRisky(toBn("20", riskyDecimals));
      let controller = await vault.controller();
      expect(controller.capRisky).to.be.equal(toBn("20", riskyDecimals));
    });
    it("check user cannot set vault cap", async function () {
      try {
        await vault
          .connect(this.wallets.alice)
          .setCapRisky(toBn("5", riskyDecimals));
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check keeper cannot set vault cap", async function () {
      try {
        await vault
          .connect(this.wallets.keeper)
          .setCapRisky(toBn("5", riskyDecimals));
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
    });
    it("check feeRecipient cannot set vault cap", async function () {
      try {
        await vault
          .connect(this.wallets.feeRecipient)
          .setCapRisky(toBn("5", riskyDecimals));
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Ownable: caller is not the owner");
      }
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
        fromBn((await vault.controller()).strike, stableDecimals)
      ).to.be.equal("2");
      expect((await vault.controller()).strikeRound).to.be.equal(1);
    });
    it("correctly set sigma", async function () {
      await vault.connect(this.wallets.keeper).setSigma(toBn("0.8", 4));
      expect(fromBn((await vault.controller()).sigma, 4)).to.be.equal("0.8");
      expect((await vault.controller()).sigmaRound).to.be.equal(1);
    });
    it("correctly set gamma", async function () {
      await vault.connect(this.wallets.keeper).setGamma(toBn("0.95", 4));
      expect(fromBn((await vault.controller()).gamma, 4)).to.be.equal("0.95");
      expect((await vault.controller()).gammaRound).to.be.equal(1);
    });
    it("correctly set delta", async function () {
      await vault.connect(this.wallets.keeper).setDelta(toBn("0.25", 4));
      expect(fromBn((await vault.controller()).delta, 4)).to.be.equal("0.25");
      expect((await vault.controller()).deltaRound).to.be.equal(1);
    });
  });

  /**
   * @notice Test depositing into vault
   * @dev This does not test rollover nor pool creation
   */
  describe("check depositing into vault", function () {
    it("correct account balances post deposit", async function () {
      let aliceStart = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.alice.address),
        riskyDecimals
      );
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      // The vault should gain 5
      expect(fromBn(await vault.totalRisky(), riskyDecimals)).to.be.equal(
        // the 0.0000000000001 is from the owner's initial deposit
        "5.0000000000001"
      );
      let aliceEnd = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.alice.address),
        riskyDecimals
      );
      // Alice should lose that amount
      expect(aliceStart - aliceEnd).to.be.equal(5);
    });
    it("correct change to pending risky post single deposit", async function () {
      let vaultState: any;
      vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("0");
      // Perform the deposit
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("5");
    });
    it("correct receipt post single deposit", async function () {
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      var receipt = await vault.depositReceipts(this.wallets.alice.address);
      expect(receipt.round).to.be.equal(1);
      expect(fromBn(receipt.riskyToDeposit, riskyDecimals)).to.be.equal("5");
      expect(fromBn(receipt.ownedShares, 1)).to.be.equal("0");
    });
    it("correct account balances post double deposit", async function () {
      let aliceStart = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.alice.address),
        riskyDecimals
      );
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      await vault.connect(this.wallets.alice).deposit(toBn("2", riskyDecimals));
      let aliceEnd = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.alice.address),
        riskyDecimals
      );
      // Alice should lose that amount
      expect(aliceStart - aliceEnd).to.be.equal(7);
    });
    it("correct change to pending risky post double deposit", async function () {
      let vaultState: any;
      vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("0");
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      await vault.connect(this.wallets.alice).deposit(toBn("2", riskyDecimals));
      vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("7");
    });
    it("correct receipt post double deposit", async function () {
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      await vault.connect(this.wallets.alice).deposit(toBn("2", riskyDecimals));
      var receipt = await vault.depositReceipts(this.wallets.alice.address);
      expect(receipt.round).to.be.equal(1);
      expect(fromBn(receipt.riskyToDeposit, riskyDecimals)).to.be.equal("7");
      expect(fromBn(receipt.ownedShares, 1)).to.be.equal("0");
    });
    it("check cannot deposit more than default cap", async function () {
      try {
        await vault
          .connect(this.wallets.alice)
          .deposit(toBn("20", riskyDecimals));
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Vault exceeds cap");
      }
    });
    it("check cannot double deposit more than default cap", async function () {
      await vault.connect(this.wallets.alice).deposit(toBn("9", riskyDecimals));
      try {
        await vault
          .connect(this.wallets.alice)
          .deposit(toBn("1", riskyDecimals));
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Vault exceeds cap");
      }
    });
    it("check cannot over deposit with new cap", async function () {
      await vault.setCapRisky(toBn("5", riskyDecimals));
      try {
        await vault
          .connect(this.wallets.alice)
          .deposit(toBn("5", riskyDecimals));
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Vault exceeds cap");
      }
    });
    it("check cap cannot be set to be below owned assets", async function () {
      await vault.setCapRisky(toBn("5", riskyDecimals));
      try {
        await vault.setCapRisky(toBn("1", riskyDecimals));
        expect(false);
      } catch (err) {
        console.log(err.message);
      }
    });
  });

  /**
   * @notice Test vault deployment
   * @dev This will call `_prepareNextPool` as well as `_deployPool`
   */
  describe("check vault deployment", function () {
    it("check keeper can deploy vault", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
    });
    it("User cannot deploy vault", async function () {
      try {
        await vault.connect(this.wallets.alice).deployVault();
        expect(false); // must fail
      } catch {
        expect(true);
      }
    });
    it("Owner cannot deploy vault", async function () {
      try {
        await vault.deployVault();
        expect(false); // must fail
      } catch {
        expect(true);
      }
    });
    it("Check can deposit before deployment", async function () {
      // This is expected so we don't want on deployment to allow deposits
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      await vault.connect(this.wallets.keeper).deployVault();
      let vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("5");
    });
    it("check can deposit after deployment", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      let vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("5");
    });
    it("check pool state post deployment", async function () {
      await vault.connect(this.wallets.keeper).deployVault();

      let poolState = await vault.poolState();
      // Check nextPoolId is not empty
      expect(poolState.nextPoolId == 0).to.be.equal(false);
      // Check currPoolId is not empty
      expect(poolState.currPoolId == 0).to.be.equal(true);
      // Check currLiquidity is 0
      expect(fromBn(poolState.currLiquidity, shareDecimals)).to.be.equal("0");
      // Check nextPoolParams are not default values
      expect(
        fromBnToFloat(poolState.nextPoolParams.strike, stableDecimals)
      ).to.be.greaterThan(0);
      expect(
        fromBnToFloat(poolState.nextPoolParams.sigma, 4)
      ).to.be.greaterThan(0);
      expect(poolState.nextPoolParams.maturity).to.be.greaterThan(0);
      expect(
        fromBnToFloat(poolState.nextPoolParams.gamma, 4)
      ).to.be.greaterThan(0);
      expect(
        fromBnToFloat(poolState.nextPoolParams.riskyPerLp, riskyDecimals)
      ).to.be.greaterThan(0);
      // Check that nextPoolReadyAt is not zero
      expect(poolState.nextPoolReadyAt).to.be.greaterThan(0);
    });
    it("check vault state post deployment", async function () {
      await vault.connect(this.wallets.keeper).deployVault();

      let vaultState = await vault.vaultState();
      expect(fromBn(vaultState.lockedRisky, riskyDecimals)).to.be.equal("0");
      expect(fromBn(vaultState.lockedStable, stableDecimals)).to.be.equal("0");
    });
    it("check double deployment of same pool fails", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      try {
        await vault.connect(this.wallets.keeper).deployVault();
        expect(false);
      } catch {
        expect(true);
      }
    });
    /**
     * @notice Change the strike price to make a different pool!
     */
    it("check double deployment of different pools", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      const decimals = await this.contracts.aggregatorV3.decimals();
      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("1.2", decimals).raw
      );

      await vault.connect(this.wallets.keeper).deployVault();
    });
    /**
     * @notice Check that liquidity is extracted out of primitive pools
     * in _removeLiquidity (called in deployVault)
     */
    it("check liquidity is taken out of pool in deployment", async function () {
      // Alice makes a deposit into the vault (pending)
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));

      // Vault is started
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("0.99", await this.contracts.aggregatorV3.decimals()).raw
      );

      expect(
        fromBnToFloat(
          await this.contracts.risky.balanceOf(vault.address),
          riskyDecimals
        )
      ).to.be.closeTo(0, 0.001);

      // Do a second deployment and vault
      // Alice's pending becomes locked for this round
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("0.95", await this.contracts.aggregatorV3.decimals()).raw
      );
      // Do a third deployment. This is the first round liquidity is
      // actually taken out of a Primitive pool
      await vault.connect(this.wallets.keeper).deployVault();

      expect(
        fromBnToFloat(
          await this.contracts.risky.balanceOf(vault.address),
          riskyDecimals
        )
      ).to.not.be.closeTo(0, 0.001);
    });
  });

  /**
   * @notice Test vault rollover
   * @dev This will call `_prepareRollover` as well as `_depositLiquidity`
   *  and `_getVaultFees`
   */
  describe("check vault rollover", function () {
    it("check keeper can rollover vault", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("check user cannot rollover vault", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      try {
        await vault.connect(this.wallets.alice).rollover();
        expect(false);
      } catch {
        expect(true);
      }
    });
    it("check owner cannot rollover vault", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      try {
        await vault.connect(this.wallets.deployer).rollover();
        expect(false);
      } catch {
        expect(true);
      }
    });
    it("check rollover without deployment fails", async function () {
      try {
        await vault.connect(this.wallets.keeper).rollover();
        expect(false);
      } catch {
        expect(true);
      }
    });
    it("check vault state post rollover", async function () {
      let vaultState;

      vaultState = await vault.vaultState();
      let preRound = vaultState.round;

      // Keeper deploys fresh vault
      await vault.connect(this.wallets.keeper).deployVault();

      let [vaultRisky, vaultStable] = await getVaultBalance(
        this.contracts.risky,
        this.contracts.stable,
        vault.address,
        riskyDecimals,
        stableDecimals
      );

      let pendingRisky = fromBnToFloat(
        (await vault.vaultState()).pendingRisky,
        riskyDecimals
      );

      // Keeper rollover to new vault
      await vault.connect(this.wallets.keeper).rollover();

      // Fetch the pool state post rollover
      let poolState = await vault.poolState();

      // Compute expected locked amounts
      let feeOutput = getVaultFees(
        fromBnToFloat(vaultState.lastLockedRisky, riskyDecimals),
        fromBnToFloat(vaultState.lastLockedStable, stableDecimals),
        vaultRisky - pendingRisky,
        vaultStable,
        1.0,
        fromBnToFloat(await vault.managementFee(), 6),
        fromBnToFloat(await vault.performanceFee(), 6)
      );
      let lockOutput = getLockedAmounts(
        vaultRisky,
        vaultStable,
        feeOutput.feeRisky,
        feeOutput.feeStable,
        1.0,
        fromBnToFloat(poolState.currPoolParams.riskyPerLp, riskyDecimals),
        fromBnToFloat(poolState.currPoolParams.stablePerLp, stableDecimals)
      );

      // Check that queued variables in vault state are refreshed
      vaultState = await vault.vaultState();
      expect(
        fromBn(vaultState.lastQueuedWithdrawRisky, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lastQueuedWithdrawStable, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.totalQueuedWithdrawShares, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.currQueuedWithdrawShares, stableDecimals)
      ).to.be.equal("0");

      // Locked assets = vault assets - fees
      let lockedRisky = fromBnToFloat(vaultState.lockedRisky, riskyDecimals);
      let lockedStable = fromBnToFloat(vaultState.lockedStable, stableDecimals);

      // Check locked amount is the fee amount!
      expect(lockOutput.lockedRisky).to.be.closeTo(lockedRisky, 0.001);
      expect(lockOutput.lockedStable).to.be.closeTo(lockedStable, 0.001);

      // Check round number
      expect(vaultState.round).to.be.equal(preRound + 1);

      // Check pending amounts
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("0");

      // Check the cached round prices
      /// @dev Since totalSupply is 0, roundSharePrice will be 1
      expect(
        fromBn(await vault.roundSharePriceInRisky(preRound), riskyDecimals)
      ).to.be.equal("1");
      expect(
        fromBn(await vault.roundSharePriceInStable(preRound), stableDecimals)
      ).to.be.equal("1");
    });
    it("check pool state post rollover", async function () {
      let poolState: any;

      // Alice deposits 1 eth
      await vault.connect(this.wallets.alice).deposit(toBn("1", riskyDecimals));

      // Keeper deploys vault
      await vault.connect(this.wallets.keeper).deployVault();

      // After deployment, cache info from pool state
      poolState = await vault.poolState();
      let emptyPoolId = poolState.currPoolId;
      let cachePoolId = poolState.nextPoolId;

      // Pool State should not have any liquidity yet
      expect(fromBn(poolState.currLiquidity, shareDecimals)).to.be.equal("0");

      // Keeper rolls vault over
      await vault.connect(this.wallets.keeper).rollover();

      poolState = await vault.poolState();

      // Check pool identifiers match expected
      expect(poolState.currPoolId).to.be.equal(cachePoolId);
      expect(poolState.nextPoolId).to.be.equal(emptyPoolId);

      // Pool State now stores liquidity held by contract
      expect(
        fromBnToFloat(poolState.currLiquidity, shareDecimals)
      ).to.be.greaterThan(0);
    });
    it("check zero shares minted post rollover without deposits", async function () {
      expect(
        fromBn(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.equal("0");
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
      // Since pendingRisky is 0, no new shares are minted
      expect(
        fromBn(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.equal("0");
    });
    it("check fee recipient post rollover", async function () {
      // Prior to rollover, in a fresh vault, fee recipient should be broke
      expect(
        fromBn(
          await this.contracts.risky.balanceOf(
            this.wallets.feeRecipient.address
          ),
          riskyDecimals
        )
      ).to.be.equal("0");
      expect(
        fromBn(
          await this.contracts.stable.balanceOf(
            this.wallets.feeRecipient.address
          ),
          stableDecimals
        )
      ).to.be.equal("0");

      // Keeper does deployment
      await vault.connect(this.wallets.keeper).deployVault();

      let [vaultRisky, vaultStable] = await getVaultBalance(
        this.contracts.risky,
        this.contracts.stable,
        vault.address,
        riskyDecimals,
        stableDecimals
      );
      let pendingRisky = fromBnToFloat(
        (await vault.vaultState()).pendingRisky,
        riskyDecimals
      );

      // Keeper does rollover
      await vault.connect(this.wallets.keeper).rollover();

      // Derive fees in risky and stable assets
      let vaultState = await vault.vaultState();

      let feeOutput = getVaultFees(
        fromBnToFloat(vaultState.lastLockedRisky, riskyDecimals),
        fromBnToFloat(vaultState.lastLockedStable, stableDecimals),
        vaultRisky - pendingRisky,
        vaultStable,
        1.0,
        fromBnToFloat(await vault.managementFee(), 6),
        fromBnToFloat(await vault.performanceFee(), 6)
      );

      // Check agreement between contract and test
      expect(
        fromBnToFloat(
          await this.contracts.risky.balanceOf(
            this.wallets.feeRecipient.address
          ),
          riskyDecimals
        )
      ).to.be.closeTo(feeOutput.feeRisky, 0.001);
      expect(
        fromBnToFloat(
          await this.contracts.stable.balanceOf(
            this.wallets.feeRecipient.address
          ),
          stableDecimals
        )
      ).to.be.closeTo(feeOutput.feeStable, 0.001);
    });
    it("check rollover: swap risky for stable", async function () {
      // mint more risky to get into case 2
      await this.contracts.risky.mint(
        vault.address,
        toBn("100", riskyDecimals)
      );

      await vault.connect(this.wallets.keeper).deployVault();

      // Get raw vault balances
      let [vaultRisky, vaultStable] = await getVaultBalance(
        this.contracts.risky,
        this.contracts.stable,
        vault.address,
        riskyDecimals,
        stableDecimals
      );
      // Compute round vault fees
      let feeOutput = getVaultFees(
        fromBnToFloat(
          (await vault.vaultState()).lastLockedRisky,
          riskyDecimals
        ),
        fromBnToFloat(
          (await vault.vaultState()).lastLockedStable,
          stableDecimals
        ),
        vaultRisky,
        vaultStable,
        1.0,
        fromBnToFloat(await vault.managementFee(), 6),
        fromBnToFloat(await vault.performanceFee(), 6)
      );

      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      let poolState = await vault.poolState();

      let [optimalRisky, optimalStable] = getBestSwap(
        vaultRisky - feeOutput.feeRisky,
        vaultStable - feeOutput.feeStable,
        fromBnToFloat(poolState.currPoolParams.riskyPerLp, riskyDecimals),
        fromBnToFloat(poolState.currPoolParams.stablePerLp, stableDecimals),
        1.0
      );

      expect(
        fromBnToFloat(vaultState.lockedRisky, riskyDecimals)
      ).to.be.closeTo(optimalRisky, 1e-6);
      expect(
        fromBnToFloat(vaultState.lockedStable, stableDecimals)
      ).to.be.closeTo(optimalStable, 1e-6);
      expect(
        fromBnToFloat(poolState.currLiquidity, shareDecimals)
      ).to.be.greaterThan(0);
    });
    it("check rollover: swap stable for risky", async function () {
      // mint more stable to get into case 3
      await this.contracts.stable.mint(
        vault.address,
        toBn("100", stableDecimals)
      );
      await vault.connect(this.wallets.keeper).deployVault();

      // Get raw vault balances
      let [vaultRisky, vaultStable] = await getVaultBalance(
        this.contracts.risky,
        this.contracts.stable,
        vault.address,
        riskyDecimals,
        stableDecimals
      );
      // Compute round vault fees
      let feeOutput = getVaultFees(
        fromBnToFloat(
          (await vault.vaultState()).lastLockedRisky,
          riskyDecimals
        ),
        fromBnToFloat(
          (await vault.vaultState()).lastLockedStable,
          stableDecimals
        ),
        vaultRisky,
        vaultStable,
        1.0,
        fromBnToFloat(await vault.managementFee(), 6),
        fromBnToFloat(await vault.performanceFee(), 6)
      );

      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      let poolState = await vault.poolState();

      let [optimalRisky, optimalStable] = getBestSwap(
        vaultRisky - feeOutput.feeRisky,
        vaultStable - feeOutput.feeStable,
        fromBnToFloat(poolState.currPoolParams.riskyPerLp, riskyDecimals),
        fromBnToFloat(poolState.currPoolParams.stablePerLp, stableDecimals),
        1.0
      );

      expect(
        fromBnToFloat(vaultState.lockedRisky, riskyDecimals)
      ).to.be.closeTo(optimalRisky, 1e-6);
      expect(
        fromBnToFloat(vaultState.lockedStable, stableDecimals)
      ).to.be.closeTo(optimalStable, 1e-6);
      expect(
        fromBnToFloat(poolState.currLiquidity, shareDecimals)
      ).to.be.greaterThan(0);
    });
  });

  /**
   * @notice Test vault deploy, deposit, and rollover together
   * The following tests focus on the interactions between them
   */
  describe("check vault rollover with deposit", function () {
    beforeEach(async function () {
      // Keeper deploys vault
      await vault.connect(this.wallets.keeper).deployVault();
      // Alice deposits risky into vault
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));
      // Vault rolls over
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("check total supply of shares is non-zero", async function () {
      expect(fromBn(await vault.totalSupply(), shareDecimals)).to.be.equal("5");
    });
    it("check new shares were minted", async function () {
      let totalSupply = fromBnToFloat(await vault.totalSupply(), shareDecimals);
      expect(
        fromBn(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.equal(totalSupply.toString());
    });
    it("check depositor does not own the shares", async function () {
      expect(
        fromBn(await vault.balanceOf(this.wallets.alice.address), shareDecimals)
      ).to.be.equal("0");
    });
  });

  /**
   * @notice Check that the vault is well behaved after multiple rollovers
   * This will test a change in share price over deposits through rounds
   */
  describe("check double deposit and rollovers", function () {
    let oldLockedRisky: string;
    let oldLockedStable: string;
    let vaultRisky: number;
    let vaultStable: number;
    let pendingRisky: number;

    beforeEach(async function () {
      // Alice makes a deposit into the vault
      await vault.connect(this.wallets.alice).deposit(toBn("2", riskyDecimals));

      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
      const oracleDecimals = await this.contracts.aggregatorV3.decimals();
      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("1.2", oracleDecimals).raw
      );

      let vaultState = await vault.vaultState();
      oldLockedRisky = fromBn(vaultState.lockedRisky, riskyDecimals);
      oldLockedStable = fromBn(vaultState.lockedStable, stableDecimals);

      // Alice makes a larger deposit into the vault
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));

      await vault.connect(this.wallets.keeper).deployVault();

      [vaultRisky, vaultStable] = await getVaultBalance(
        this.contracts.risky,
        this.contracts.stable,
        vault.address,
        riskyDecimals,
        stableDecimals
      );
      pendingRisky = fromBnToFloat(
        (await vault.vaultState()).pendingRisky,
        riskyDecimals
      );

      await vault.connect(this.wallets.keeper).rollover();
    });
    it("check vault state post double rollover", async function () {
      let vaultState = await vault.vaultState();
      let poolState = await vault.poolState();

      // Check that queued amounts are zero given no withdraws
      expect(
        fromBn(vaultState.lastQueuedWithdrawRisky, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.lastQueuedWithdrawStable, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.totalQueuedWithdrawShares, stableDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(vaultState.currQueuedWithdrawShares, stableDecimals)
      ).to.be.equal("0");

      // Check that the cached locked amounts are correct
      expect(fromBn(vaultState.lastLockedRisky, riskyDecimals)).to.be.equal(
        oldLockedRisky
      );
      expect(fromBn(vaultState.lastLockedStable, stableDecimals)).to.be.equal(
        oldLockedStable
      );

      let feeOutput = getVaultFees(
        fromBnToFloat(vaultState.lastLockedRisky, riskyDecimals),
        fromBnToFloat(vaultState.lastLockedStable, stableDecimals),
        vaultRisky - pendingRisky,
        vaultStable,
        1 / 1.2,
        fromBnToFloat(await vault.managementFee(), 6),
        fromBnToFloat(await vault.performanceFee(), 6)
      );

      let lockOutput = getLockedAmounts(
        vaultRisky,
        vaultStable,
        feeOutput.feeRisky,
        feeOutput.feeStable,
        1 / 1.2,
        fromBnToFloat(poolState.currPoolParams.riskyPerLp, riskyDecimals),
        fromBnToFloat(poolState.currPoolParams.stablePerLp, stableDecimals)
      );

      expect(
        fromBnToFloat(vaultState.lockedRisky, riskyDecimals)
      ).to.be.closeTo(lockOutput.lockedRisky, 0.1);
      expect(
        fromBnToFloat(vaultState.lockedStable, stableDecimals)
      ).to.be.closeTo(lockOutput.lockedStable, 0.1);

      // Check round number
      expect(vaultState.round).to.be.equal(3);

      // Check pending amounts
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("0");
    });
    it("check pool state post double rollover", async function () {
      let poolState = await vault.poolState();
      // Check nextPoolId is empty (after rollover)
      expect(poolState.nextPoolId == 0).to.be.equal(true);
      // Check currPoolId is not empty (after rollover)
      expect(poolState.currPoolId == 0).to.be.equal(false);
      // Check currLiquidity is not zero
      expect(
        fromBnToFloat(poolState.currLiquidity, shareDecimals)
      ).to.be.greaterThan(0);
    });
    it("check round share prices post double rollover", async function () {
      expect(
        fromBn(await vault.roundSharePriceInRisky(1), riskyDecimals)
      ).to.be.equal("1");
      expect(
        fromBn(await vault.roundSharePriceInRisky(2), riskyDecimals)
      ).to.be.not.equal("1");
      expect(
        fromBn(await vault.roundSharePriceInStable(1), stableDecimals)
      ).to.be.equal("1");
      expect(
        fromBn(await vault.roundSharePriceInStable(2), stableDecimals)
      ).to.be.not.equal("1");
    });
    it("check shares minted post double rollover", async function () {
      // Since Alice deposited and has not withdrawn, minted shares exist
      expect(
        fromBnToFloat(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.greaterThan(0);
    });
  });

  /**
   * @notice Check that the fee computation is sensible
   */
  describe("check fee computation in vault success", function () {
    beforeEach(async function () {
      // Alice makes a deposit into the vault
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));

      // Vault is started
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("check out-the-money behavior", async function () {
      const oracleDecimals = await this.contracts.aggregatorV3.decimals();
      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("0.95", oracleDecimals).raw
      );

      /// @dev Simulate OTM by minting a "premium"
      await this.contracts.risky.mint(vault.address, toBn("1", riskyDecimals));

      // deploy vault removes liquidity from old one
      await vault.connect(this.wallets.keeper).deployVault();

      let [vaultRisky, vaultStable] = await getVaultBalance(
        this.contracts.risky,
        this.contracts.stable,
        vault.address,
        riskyDecimals,
        stableDecimals
      );

      let pendingRisky = fromBnToFloat(
        (await vault.vaultState()).pendingRisky,
        riskyDecimals
      );

      // Puts liquidity into new vault
      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      let poolState = await vault.poolState();

      // Compute locked amounts
      let feeOutput = getVaultFees(
        fromBnToFloat(vaultState.lastLockedRisky, riskyDecimals),
        fromBnToFloat(vaultState.lastLockedStable, stableDecimals),
        vaultRisky - pendingRisky,
        vaultStable,
        1 / 0.95,
        fromBnToFloat(await vault.managementFee(), 6),
        fromBnToFloat(await vault.performanceFee(), 6)
      );
      let lockOutput = getLockedAmounts(
        vaultRisky,
        vaultStable,
        feeOutput.feeRisky,
        feeOutput.feeStable,
        1 / 0.95,
        fromBnToFloat(poolState.currPoolParams.riskyPerLp, riskyDecimals),
        fromBnToFloat(poolState.currPoolParams.stablePerLp, stableDecimals)
      );

      // Locked assets = vault assets - fees
      let lockedRisky = fromBnToFloat(vaultState.lockedRisky, riskyDecimals);
      let lockedStable = fromBnToFloat(vaultState.lockedStable, stableDecimals);

      expect(lockOutput.lockedRisky).to.be.closeTo(lockedRisky, 0.001);
      expect(lockOutput.lockedStable).to.be.closeTo(lockedStable, 0.001);

      // For this setup, fee in stable ~ 0
      expect(feeOutput.feeRisky).to.be.greaterThan(0);
      expect(feeOutput.feeStable).to.be.greaterThan(0);
    });
    it("check in-the-money behavior", async function () {
      const oracleDecimals = await this.contracts.aggregatorV3.decimals();
      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("1.2", oracleDecimals).raw
      );

      await vault.connect(this.wallets.keeper).deployVault();

      /// @dev no minting is needed here because expires OTM
      let [vaultRisky, vaultStable] = await getVaultBalance(
        this.contracts.risky,
        this.contracts.stable,
        vault.address,
        riskyDecimals,
        stableDecimals
      );

      let pendingRisky = fromBnToFloat(
        (await vault.vaultState()).pendingRisky,
        riskyDecimals
      );

      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      let poolState = await vault.poolState();

      let feeOutput = getVaultFees(
        fromBnToFloat(vaultState.lastLockedRisky, riskyDecimals),
        fromBnToFloat(vaultState.lastLockedStable, stableDecimals),
        vaultRisky - pendingRisky,
        vaultStable,
        1 / 1.2,
        fromBnToFloat(await vault.managementFee(), 6),
        fromBnToFloat(await vault.performanceFee(), 6)
      );
      let lockOutput = getLockedAmounts(
        vaultRisky,
        vaultStable,
        feeOutput.feeRisky,
        feeOutput.feeStable,
        1 / 1.2,
        fromBnToFloat(poolState.currPoolParams.riskyPerLp, riskyDecimals),
        fromBnToFloat(poolState.currPoolParams.stablePerLp, stableDecimals)
      );

      let lockedRisky = fromBnToFloat(vaultState.lockedRisky, riskyDecimals);
      let lockedStable = fromBnToFloat(vaultState.lockedStable, stableDecimals);

      expect(lockOutput.lockedRisky).to.be.closeTo(lockedRisky, 0.001);
      expect(lockOutput.lockedStable).to.be.closeTo(lockedStable, 0.001);

      expect(feeOutput.feeRisky).to.be.closeTo(0, 0.001);
      expect(feeOutput.feeStable).to.be.closeTo(0, 0.001);
    });
  });

  /**
   * @notice Test account queries
   */
  describe("check account statistics", function () {
    it("check default account shares", async function () {
      let shares = await vault.getAccountShares(this.wallets.alice.address);
      expect(fromBn(shares, shareDecimals)).to.be.equal("0");
    });
    it("check default account balance", async function () {
      let [riskyBalance, stableBalance] = await vault.getAccountBalance(
        this.wallets.alice.address
      );
      /// @dev this is amount of risky and stable held in vault for account
      /// not the amount owned by the user's wallet
      expect(fromBn(riskyBalance, riskyDecimals)).to.be.equal("0");
      expect(fromBn(stableBalance, stableDecimals)).to.be.equal("0");
    });
    it("check account shares after rollover", async function () {
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));

      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let shares = await vault.getAccountShares(this.wallets.alice.address);
      expect(fromBnToFloat(shares, shareDecimals)).to.be.greaterThan(0);
    });
    it("check account balance after rollover", async function () {
      let [riskyBalance, stableBalance] = await vault.getAccountBalance(
        this.wallets.alice.address
      );

      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));

      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      [riskyBalance, stableBalance] = await vault.getAccountBalance(
        this.wallets.alice.address
      );

      expect(fromBnToFloat(riskyBalance, riskyDecimals)).to.be.greaterThan(0);
      expect(fromBnToFloat(stableBalance, stableDecimals)).to.be.greaterThan(0);
    });
  });

  /**
   * @notice Test withdrawal requests and completion
   */
  describe("check user withdraw", function () {
    beforeEach(async function () {
      // Alice makes a deposit into the vault
      await vault.connect(this.wallets.alice).deposit(toBn("5", riskyDecimals));

      // Vault is started
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("0.99", await this.contracts.aggregatorV3.decimals()).raw
      );

      // Do a second deployment and vault
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("correct request withdrawal behavior", async function () {
      let shares = await vault.getAccountShares(this.wallets.alice.address);
      await vault.connect(this.wallets.alice).requestWithdraw(shares);

      // Check vault state is updated
      let vaultState = await vault.vaultState();
      expect(
        fromBn(vaultState.currQueuedWithdrawShares, shareDecimals)
      ).to.be.equal("5");

      // Check pending withdraws are updated
      let pendingWithdraw = await vault.pendingWithdraw(
        this.wallets.alice.address
      );
      expect(pendingWithdraw.round).to.be.equal(vaultState.round);
      expect(fromBn(pendingWithdraw.shares, shareDecimals)).to.be.equal(
        fromBn(shares, shareDecimals)
      );
    });
    it("cannot complete withdrawal in same round as request", async function () {
      let shares = await vault.getAccountShares(this.wallets.alice.address);
      await vault.connect(this.wallets.alice).requestWithdraw(shares);
      try {
        await vault.connect(this.wallets.alice).completeWithdraw();
        expect(false);
      } catch (err) {
        expect(err.message).to.include("Too early to withdraw");
      }
    });
    it("correct completing withdrawal behavior", async function () {
      let shares = await vault.getAccountShares(this.wallets.alice.address);
      await vault.connect(this.wallets.alice).requestWithdraw(shares);
      let oldState = await vault.vaultState();

      // Save amount of risky and stable owed by alice
      let aliceOldRisky = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.alice.address),
        riskyDecimals
      );
      let aliceOldStable = fromBnToFloat(
        await this.contracts.stable.balanceOf(this.wallets.alice.address),
        stableDecimals
      );

      // Rollover to the next round
      // Change price to make pool unique (since old pool still exists)
      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("0.95", await this.contracts.aggregatorV3.decimals()).raw
      );
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let midState = await vault.vaultState();
      expect(midState.round).to.be.equal(oldState.round + 1);

      // User completes the withdrawal
      await vault.connect(this.wallets.alice).completeWithdraw();

      // Overwrite state again to get post complete-withdraw state
      let newState = await vault.vaultState();
      expect(newState.round).to.be.equal(oldState.round + 1);

      // Check last queued is 0 for both risky and stable since alice
      // was the only liquidity provider
      expect(
        fromBn(newState.lastQueuedWithdrawRisky, riskyDecimals)
      ).to.be.equal("0");
      expect(
        fromBn(newState.lastQueuedWithdrawStable, stableDecimals)
      ).to.be.equal("0");
      // Rollover should reset the curr queued shares for withdrawal
      expect(
        fromBn(newState.currQueuedWithdrawShares, shareDecimals)
      ).to.be.equal("0");
      // Withdrawal also subtracts the old currQueuedWithdrawShares from
      // totalQueuedWithdrawShares, which in this case, results in zero
      expect(
        fromBn(newState.totalQueuedWithdrawShares, shareDecimals)
      ).to.be.equal("0");
      // After rollover, totalQueuedWithdrawShares should equal the amount
      // currQueuedWithdrawShares before rollover
      expect(
        fromBn(midState.totalQueuedWithdrawShares, shareDecimals)
      ).to.be.equal(fromBn(oldState.currQueuedWithdrawShares, shareDecimals));

      // Check the pending withdraws cache is reset to zero
      let pendingWithdraw = await vault.pendingWithdraw(
        this.wallets.alice.address
      );
      expect(fromBn(pendingWithdraw.shares, shareDecimals)).to.be.equal("0");

      // Check no shares remaining (all burned)
      expect(
        fromBn(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.equal("0");

      // Check that alice has more tokens than before
      let aliceNewRisky = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.alice.address),
        riskyDecimals
      );
      let aliceNewStable = fromBnToFloat(
        await this.contracts.stable.balanceOf(this.wallets.alice.address),
        stableDecimals
      );

      // Since only Alice is withdrawing as the only LP - this logic does not
      // hold if more than one individual is withdrawing
      let withdrawnRisky = fromBnToFloat(
        midState.lastQueuedWithdrawRisky,
        riskyDecimals
      );
      let withdrawnStable = fromBnToFloat(
        midState.lastQueuedWithdrawStable,
        stableDecimals
      );
      expect(aliceNewRisky).to.be.equal(aliceOldRisky + withdrawnRisky);
      expect(aliceNewStable).to.be.equal(aliceOldStable + withdrawnStable);
    });
    it("try completion without withdrawal request", async function () {
      try {
        await vault.connect(this.wallets.alice).completeWithdraw();
      } catch (err) {
        expect(err.message).to.include("!sharesToWithdraw");
      }
    });
    it("test two withdrawals in same round", async function () {
      let shares = await vault.getAccountShares(this.wallets.alice.address);
      // Withdraw in 2 segments
      await vault.connect(this.wallets.alice).requestWithdraw(shares.div(2));
      await vault.connect(this.wallets.alice).requestWithdraw(shares.div(2));

      let pendingWithdraw = await vault.pendingWithdraw(
        this.wallets.alice.address
      );
      expect(fromBn(pendingWithdraw.shares, shareDecimals)).to.be.equal(
        fromBn(shares, shareDecimals)
      );
    });
  });

  /**
   * @notice Test public getter functions
   */
  describe("check public getter functions", function () {
    it("correct default amount of total risky assets", async function () {
      expect(fromBn(await vault.totalRisky(), riskyDecimals)).to.be.equal(
        fromBn(BigNumber.from(100000), riskyDecimals).toString()
      );
    });
    it("correct default amount of total stable assets", async function () {
      expect(fromBn(await vault.totalStable(), stableDecimals)).to.be.equal(
        fromBn(BigNumber.from(100000), stableDecimals).toString()
      );
    });
    it("correct non-zero amount of total risky assets", async function () {
      await this.contracts.risky.mint(vault.address, parseWei("1").raw);
      let seededAmount = fromBnToFloat(BigNumber.from(100000), riskyDecimals);
      let mintedAmount = fromBnToFloat(parseWei("1").raw, riskyDecimals);
      expect(fromBn(await vault.totalRisky(), riskyDecimals)).to.be.equal(
        (seededAmount + mintedAmount).toString()
      );
    });
    it("correct non-zero amount of total stable assets", async function () {
      await this.contracts.stable.mint(vault.address, parseWei("1").raw);
      let seededAmount = fromBnToFloat(BigNumber.from(100000), stableDecimals);
      let mintedAmount = fromBnToFloat(parseWei("1").raw, stableDecimals);
      expect(fromBn(await vault.totalStable(), stableDecimals)).to.be.equal(
        (seededAmount + mintedAmount).toString()
      );
    });
  });
});
