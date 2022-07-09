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
let primitiveDecimals: number;

/**
 * @notice Similar to `vault.test.ts` except we use the test contract
 *         `TestParetoVault` to access internal functions of `ParetoVault`.
 *         Allows for more granular tests
 */
runTest("TestParetoVault", function () {
  beforeEach(async function () {
    const TestParetoVault = await hre.ethers.getContractFactory(
      "TestParetoVault"
    );
    vault = await TestParetoVault.connect(this.wallets.deployer).deploy(
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
    const deployFee = vault.MIN_LIQUIDITY();
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
    primitiveDecimals = (await vault.primitiveParams()).decimals;

    // Grant vault permission from Alice
    await this.contracts.risky
      .connect(this.wallets.alice)
      .increaseAllowance(vault.address, constants.MaxUint256);
    await this.contracts.stable
      .connect(this.wallets.alice)
      .increaseAllowance(vault.address, constants.MaxUint256);
  });
  describe("Test internal deposit processing", function () {
    beforeEach(async function () {
      let riskyAmount = parseWei("1.2", riskyDecimals).raw;
      let creditor = this.wallets.alice.address;
      await vault.testProcessDeposit(riskyAmount, creditor);
    });
    it("Check deposit receipt updated", async function () {
      let receipt = await vault.depositReceipts(this.wallets.alice.address);
      expect(receipt.round).to.be.equal(1);
      expect(fromBn(receipt.riskyToDeposit, riskyDecimals)).to.be.equal("1.2");
      // User should have no owned shares from previous rounds
      expect(fromBn(receipt.ownedShares, shareDecimals)).to.be.equal("0");
    });
    it("Check pending risky updated", async function () {
      let vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("1.2");
    });
    it("Check shares increase after rollover", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let riskyAmount = parseWei("2", riskyDecimals).raw;
      let creditor = this.wallets.alice.address;
      await vault.testProcessDeposit(riskyAmount, creditor);
      let receipt = await vault.depositReceipts(this.wallets.alice.address);

      // In this next round, we no longer expect Alice to own zero shares
      expect(receipt.round).to.be.equal(2);
      expect(fromBn(receipt.riskyToDeposit, riskyDecimals)).to.be.equal("2");
      expect(
        fromBnToFloat(receipt.ownedShares, shareDecimals)
      ).to.be.greaterThan(0);
    });
    it("Check contract has minted new shares", async function () {
      // User depositing should translate to new shares
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
      expect(
        fromBn(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.equal("1.2");
    });
  });

  describe("Test internal deposit of liquidity into RMM pool", function () {
    beforeEach(async function () {
      // Deploy a Vault
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      // Mint 1 token of each asset
      await this.contracts.risky.mint(
        vault.address,
        parseWei("1", riskyDecimals).raw
      );
      await this.contracts.stable.mint(
        vault.address,
        parseWei("1", stableDecimals).raw
      );
    });
    it("Check resources were placed in pool", async function () {
      let poolState = await vault.poolState();

      let riskyPreBalance = fromBnToFloat(
        await this.contracts.risky.balanceOf(vault.address),
        riskyDecimals
      );
      let stablePreBalance = fromBnToFloat(
        await this.contracts.risky.balanceOf(vault.address),
        stableDecimals
      );

      await vault.testDepositLiquidity(
        poolState.currPoolId,
        parseWei("0.1", riskyDecimals).raw,
        parseWei("0.1", stableDecimals).raw
      );

      let riskyPostBalance = fromBnToFloat(
        await this.contracts.risky.balanceOf(vault.address),
        riskyDecimals
      );
      let stablePostBalance = fromBnToFloat(
        await this.contracts.risky.balanceOf(vault.address),
        stableDecimals
      );
      expect(riskyPreBalance - riskyPostBalance).to.be.closeTo(0.1, 1e-6);
      expect(stablePreBalance - stablePostBalance).to.be.closeTo(0.1, 1e-6);
    });
    it("Check pool owns deposited resoures", async function () {
      let poolState = await vault.poolState();
      await vault.testDepositLiquidity(
        poolState.currPoolId,
        parseWei("0.1", riskyDecimals).raw,
        parseWei("0.1", stableDecimals).raw
      );
      let engine = (await vault.primitiveParams()).engine;
      expect(
        fromBnToFloat(
          await this.contracts.risky.balanceOf(engine),
          riskyDecimals
        )
      ).to.be.closeTo(0.1, 1e-6);
      expect(
        fromBnToFloat(
          await this.contracts.stable.balanceOf(engine),
          stableDecimals
        )
      ).to.be.closeTo(0.1, 1e-6);
    });
  });

  describe("Test internal withdrawal request", function () {
    beforeEach(async function () {
      let riskyAmount = parseWei("1", riskyDecimals).raw;
      await vault.testProcessDeposit(riskyAmount, this.wallets.alice.address);
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("Check default shares in pending withdraws is zero", async function () {
      let withdraw = await vault.pendingWithdraw(this.wallets.alice.address);
      expect(withdraw.round).to.be.equal(0);
      expect(fromBn(withdraw.shares, shareDecimals)).to.be.equal("0");
    });
    it("Check pending withdrawal shares is updated", async function () {
      await vault
        .connect(this.wallets.alice)
        .testRequestWithdraw(toBn("1", shareDecimals));
      let withdraw = await vault.pendingWithdraw(this.wallets.alice.address);
      expect(withdraw.round).to.be.equal(2);
      expect(fromBn(withdraw.shares, shareDecimals)).to.be.equal("1");
    });
    it("Check two withdrawal requests in the same round", async function () {
      await vault
        .connect(this.wallets.alice)
        .testRequestWithdraw(toBn("1", shareDecimals));
      await vault
        .connect(this.wallets.alice)
        .testRequestWithdraw(toBn("0.5", shareDecimals));
      let withdraw = await vault.pendingWithdraw(this.wallets.alice.address);
      expect(withdraw.round).to.be.equal(2);
      expect(fromBn(withdraw.shares, shareDecimals)).to.be.equal("1.5");
    });
    it("Try withdrawing more than the user owns", async function () {
      try {
        await vault
          .connect(this.wallets.alice)
          .requestWithdraw(toBn("100", shareDecimals));
      } catch (err) {
        expect(err.message).to.include("!shares");
      }
    });
    it("Try withdrawing more than the user owns in many segments", async function () {
      await vault
        .connect(this.wallets.alice)
        .requestWithdraw(toBn("1", shareDecimals));
      try {
        await vault
          .connect(this.wallets.alice)
          .requestWithdraw(toBn("1", shareDecimals));
      } catch (err) {
        expect(err.message).to.include("!shares");
      }
    });
  });

  describe("Test internal withdrawal completion", function () {
    beforeEach(async function () {
      let riskyAmount = parseWei("1", riskyDecimals).raw;
      await vault.connect(this.wallets.alice).deposit(riskyAmount);
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
      /// @dev Call `requestWithdraw` instead of `testRequestWithdraw` to update
      ///      `vaultState.currQueuedWithdrawShares`
      await vault
        .connect(this.wallets.alice)
        .requestWithdraw(toBn("1", shareDecimals));
    });
    it("Check total queued shares to withdraw is non-zero", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      expect(
        fromBnToFloat(vaultState.totalQueuedWithdrawShares, shareDecimals)
      ).to.be.greaterThan(0);
    });
    it("Error if completing withdrawal before round rollover", async function () {
      try {
        await vault.connect(this.wallets.alice).testCompleteWithdraw();
      } catch (err) {
        expect(err.message).to.include("Too early to withdraw");
      }
    });
    it("Success if completing withdrawal after round rollover", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
      await vault.connect(this.wallets.alice).testCompleteWithdraw();
    });
    it("Check total queued withdraw shares is reset", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
      await vault.connect(this.wallets.alice).testCompleteWithdraw();

      let vaultState = await vault.vaultState();
      expect(
        fromBn(vaultState.totalQueuedWithdrawShares, shareDecimals)
      ).to.be.equal("0");
    });
    it("Check pending shares withdraw is set to zero", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
      await vault.connect(this.wallets.alice).testCompleteWithdraw();

      let withdraw = await vault.pendingWithdraw(this.wallets.alice.address);
      expect(fromBn(withdraw.shares, shareDecimals)).to.be.equal("0");
    });
    it("Check shares are burned post withdrawal", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
      expect(
        fromBnToFloat(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.greaterThan(0);
      await vault.connect(this.wallets.alice).testCompleteWithdraw();
      expect(
        fromBnToFloat(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.equal(0);
    });
    it("Check user receives tokens upon withdrawal", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let riskyAlicePre = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.alice.address),
        riskyDecimals
      );
      let stableAlicePre = fromBnToFloat(
        await this.contracts.stable.balanceOf(this.wallets.alice.address),
        stableDecimals
      );
      let riskyVaultPre = fromBnToFloat(
        await this.contracts.risky.balanceOf(vault.address),
        riskyDecimals
      );
      let stableVaultPre = fromBnToFloat(
        await this.contracts.stable.balanceOf(vault.address),
        stableDecimals
      );

      await vault.connect(this.wallets.alice).testCompleteWithdraw();

      let riskyAlicePost = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.alice.address),
        riskyDecimals
      );
      let stableAlicePost = fromBnToFloat(
        await this.contracts.stable.balanceOf(this.wallets.alice.address),
        stableDecimals
      );
      let riskyVaultPost = fromBnToFloat(
        await this.contracts.risky.balanceOf(vault.address),
        riskyDecimals
      );
      let stableVaultPost = fromBnToFloat(
        await this.contracts.stable.balanceOf(vault.address),
        stableDecimals
      );

      expect(riskyAlicePre + riskyVaultPre).to.be.equal(riskyAlicePost);
      expect(stableAlicePre + stableVaultPre).to.be.equal(stableAlicePost);
      expect(riskyVaultPost).to.be.equal(0);
      expect(stableVaultPost).to.be.equal(0);
    });
  });

  describe("Test internal withdrawal of liquidity from RMM pool", function () {
    beforeEach(async function () {
      // Deploy a Vault
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      // Mint 1 token of each asset
      await this.contracts.risky.mint(
        vault.address,
        parseWei("1", riskyDecimals).raw
      );
      await this.contracts.stable.mint(
        vault.address,
        parseWei("1", stableDecimals).raw
      );
    });
    it("Try removing liquidity without depositing", async function () {
      let poolState = await vault.poolState();
      try {
        await vault.testRemoveLiquidity(
          poolState.currPoolId,
          toBn("1", primitiveDecimals)
        );
        expect(false);
      } catch {
        expect(true);
      }
    });
    it("Check removing liquidity returns correct amount", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(parseWei("1", riskyDecimals).raw);
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let poolState = await vault.poolState();
      let liquidity = fromBnToFloat(poolState.currLiquidity, primitiveDecimals);

      await vault.testRemoveLiquidity(
        poolState.currPoolId,
        toBn(liquidity.toString(), primitiveDecimals)
      );
    });
    it("Check removing too much liquidity errors", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(parseWei("1", riskyDecimals).raw);
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let poolState = await vault.poolState();
      let liquidity = fromBnToFloat(poolState.currLiquidity, primitiveDecimals);

      try {
        await vault.testRemoveLiquidity(
          poolState.currPoolId,
          toBn((liquidity + 1).toString(), primitiveDecimals)
        );
        expect(false);
      } catch {
        expect(true);
      }
    });
  });

  describe("Test internal next pool preparation", function () {
    beforeEach(async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("Correctly sets spot for next pool", async function () {
      let poolState = await vault.poolState();
      // Set the oracle price
      await this.contracts.aggregatorV3.setLatestAnswer(
        parseWei("0.95", await this.contracts.aggregatorV3.decimals()).raw
      );
      await vault.testPrepareNextPool(poolState.currPoolId);
      poolState = await vault.poolState();
      let spot = fromBnToFloat(
        poolState.nextPoolParams.spotAtCreation,
        stableDecimals
      );
      expect(spot).to.be.equal(1 / 0.95);
    });
    it("Correctly sets next strike price", async function () {
      let poolState = await vault.poolState();
      await vault.testPrepareNextPool(poolState.currPoolId);
      poolState = await vault.poolState();
      expect(poolState.nextPoolParams.strike).to.be.equal(
        await this.contracts.vaultManager.getNextStrikePrice()
      );
    });
    it("Correctly sets next sigma", async function () {
      let poolState = await vault.poolState();
      await vault.testPrepareNextPool(poolState.currPoolId);
      poolState = await vault.poolState();
      expect(poolState.nextPoolParams.sigma).to.be.equal(
        await this.contracts.vaultManager.getNextVolatility()
      );
    });
    it("Correctly sets next maturity", async function () {
      let poolState = await vault.poolState();
      let maturity = await vault.testGetNextMaturity(poolState.currPoolId);
      await vault.testPrepareNextPool(poolState.currPoolId);
      poolState = await vault.poolState();
      expect(poolState.nextPoolParams.maturity).to.be.equal(maturity);
    });
    it("Correctly sets next gamma", async function () {
      let poolState = await vault.poolState();
      await vault.testPrepareNextPool(poolState.currPoolId);
      poolState = await vault.poolState();
      expect(poolState.nextPoolParams.gamma).to.be.equal(
        await this.contracts.vaultManager.getNextGamma()
      );
    });
    it("Correctly sets next riskyPerLp", async function () {
      let poolState = await vault.poolState();
      await vault.testPrepareNextPool(poolState.currPoolId);
      poolState = await vault.poolState();
      expect(
        fromBnToFloat(poolState.nextPoolParams.riskyPerLp, riskyDecimals)
      ).to.be.greaterThan(0);
      expect(
        fromBnToFloat(poolState.nextPoolParams.riskyPerLp, riskyDecimals)
      ).to.be.lessThan(1);
    });
    it("Correctly sets next stablePerLp", async function () {
      let poolState = await vault.poolState();
      await vault.testPrepareNextPool(poolState.currPoolId);
      poolState = await vault.poolState();
      expect(
        fromBnToFloat(poolState.nextPoolParams.stablePerLp, stableDecimals)
      ).to.be.greaterThan(0);
      expect(
        fromBnToFloat(poolState.nextPoolParams.stablePerLp, stableDecimals)
      ).to.be.lessThan(1);
    });
  });

  describe("Test internal rollover preparation", function () {
    beforeEach(async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("Error if double rollover on same vault", async function () {
      try {
        await vault.connect(this.wallets.keeper).testPrepareRollover();
      } catch (err) {
        expect(err.message).to.include("!newPoolId");
      }
    });
    it("Check that pending risky is reset to zero", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).testPrepareRollover();
      let vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("0");
    });
    it("Check that round is increased", async function () {
      let round = (await vault.vaultState()).round;
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).testPrepareRollover();
      expect((await vault.vaultState()).round).to.be.equal(round + 1);
    });
    it("Check that round share prices are updated", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      // For this round, totalSupply() > 0
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).testPrepareRollover();
      let round = (await vault.vaultState()).round;

      // @dev -1 from round because round gets incremented end of rollover
      expect(
        fromBnToFloat(
          await vault.roundSharePriceInRisky(round - 1),
          riskyDecimals
        )
      ).to.be.greaterThan(0.1);

      expect(
        fromBnToFloat(
          await vault.roundSharePriceInStable(round - 1),
          stableDecimals
        )
      ).to.be.greaterThan(0.1);
    });
    it("Check that current pool identifier is not empty", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).testPrepareRollover();
      let poolState = await vault.poolState();
      expect(poolState.currPoolId).to.be.not.equal(
        "0x0000000000000000000000000000000000000000000000000000000000000000"
      );
    });
    it("Check that next pool identifier is empty", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).testPrepareRollover();
      let poolState = await vault.poolState();
      expect(poolState.nextPoolId).to.be.equal(
        "0x0000000000000000000000000000000000000000000000000000000000000000"
      );
    });
    it("Check that new shares were correctly minted", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).testPrepareRollover();
      expect(
        fromBnToFloat(await vault.balanceOf(vault.address), shareDecimals)
      ).to.be.greaterThan(0);
    });
    it("Check that fees were correctly transferred to fee receipient", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));

      let keeperRisky = fromBnToFloat(
        await this.contracts.risky.balanceOf(this.wallets.feeRecipient.address),
        riskyDecimals
      );
      let keeperStable = fromBnToFloat(
        await this.contracts.stable.balanceOf(
          this.wallets.feeRecipient.address
        ),
        stableDecimals
      );

      await vault.connect(this.wallets.keeper).deployVault();

      // Simulate premiums from minting
      await this.contracts.risky.mint(
        vault.address,
        parseWei("1", riskyDecimals).raw
      );
      await this.contracts.stable.mint(
        vault.address,
        parseWei("1", stableDecimals).raw
      );

      await vault.connect(this.wallets.keeper).testPrepareRollover();

      // Check that keeper has more assets now
      expect(
        fromBnToFloat(
          await this.contracts.risky.balanceOf(
            this.wallets.feeRecipient.address
          ),
          riskyDecimals
        )
      ).to.be.greaterThan(keeperRisky);
      expect(
        fromBnToFloat(
          await this.contracts.stable.balanceOf(
            this.wallets.feeRecipient.address
          ),
          stableDecimals
        )
      ).to.be.greaterThan(keeperStable);
    });
  });

  describe("Test internal rebalancing", function () {});

  describe("Test internal optimal swap computation", function () {
    it("Check best swap computation: test 1/3", async function () {
      let [riskyBest, stableBest] = await vault.testGetBestSwap(
        toBn("1", riskyDecimals),
        toBn("1", stableDecimals),
        toBn("1", stableDecimals),
        toBn("0.8", riskyDecimals),
        toBn("0.2", stableDecimals),
      );
      riskyBest = fromBn(riskyBest, riskyDecimals);
      stableBest = fromBn(stableBest, stableDecimals);
      expect(riskyBest).to.be.equal("1.6");
      expect(stableBest).to.be.equal("0.4");
    });
    it("Check best swap computation: test 2/3", async function () {
      let [riskyBest, stableBest] = await vault.testGetBestSwap(
        toBn("2.5", riskyDecimals),
        toBn("0.8", stableDecimals),
        toBn("1.2", stableDecimals),
        toBn("0.4", riskyDecimals),
        toBn("0.6", stableDecimals),
      );
      riskyBest = fromBn(riskyBest, riskyDecimals);
      stableBest = fromBn(stableBest, stableDecimals);
      expect(riskyBest).to.be.equal("1.407407407407407407");
      expect(stableBest).to.be.equal("2.111111111111111111");
    });
    it("Check best swap computation: test 3/3", async function () {
      let [riskyBest, stableBest] = await vault.testGetBestSwap(
        toBn("0.4", riskyDecimals),
        toBn("4.1", stableDecimals),
        toBn("0.7", stableDecimals),
        toBn("0.4", riskyDecimals),
        toBn("0.9", stableDecimals),
      );
      riskyBest = fromBn(riskyBest, riskyDecimals);
      stableBest = fromBn(stableBest, stableDecimals);
      expect(riskyBest).to.be.equal("1.484745762711864406");
      expect(stableBest).to.be.equal("3.340677966101694915");
    });
  });

  describe("Test internal vault success checking", function () {
    beforeEach(async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("First round should not have vault success", async function () {
      let vaultState = await vault.vaultState();
      let currRisky = await this.contracts.risky.balanceOf(vault.address);
      let currStable = await this.contracts.stable.balanceOf(vault.address);
      let [success, , valueForPerformanceFee] =
        await vault.testCheckVaultSuccess({
          preVaultRisky: vaultState.lastLockedRisky,
          preVaultStable: vaultState.lastLockedStable,
          postVaultRisky: currRisky - vaultState.pendingRisky,
          postVaultStable: currStable,
        });
      expect(success).to.be.equal(false);
      expect(fromBn(valueForPerformanceFee, riskyDecimals)).to.be.equal("0");
    });

    it("No vault success without premium", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      let currRisky = await this.contracts.risky.balanceOf(vault.address);
      let currStable = await this.contracts.stable.balanceOf(vault.address);
      let [success, , valueForPerformanceFee] =
        await vault.testCheckVaultSuccess({
          preVaultRisky: vaultState.lastLockedRisky,
          preVaultStable: vaultState.lastLockedStable,
          postVaultRisky: currRisky - vaultState.pendingRisky,
          postVaultStable: currStable,
        });
      expect(success).to.be.equal(false);
      expect(fromBn(valueForPerformanceFee, riskyDecimals)).to.be.equal("0");
    });

    it("Check vault success with deposit", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));

      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      let currRisky = await this.contracts.risky.balanceOf(vault.address);
      let currStable = await this.contracts.stable.balanceOf(vault.address);
      let [success, , valueForPerformanceFee] =
        await vault.testCheckVaultSuccess({
          preVaultRisky: vaultState.lastLockedRisky,
          preVaultStable: vaultState.lastLockedStable,
          postVaultRisky: currRisky - vaultState.pendingRisky,
          postVaultStable: currStable,
        });
      expect(success).to.be.equal(true);
      expect(fromBn(valueForPerformanceFee)).to.be.not.equal("0");
    });
    it("Check vault success with minting", async function () {
      await vault.connect(this.wallets.keeper).deployVault();

      await this.contracts.risky.mint(
        vault.address,
        parseWei("1", riskyDecimals).raw
      );
      await this.contracts.stable.mint(
        vault.address,
        parseWei("1", stableDecimals).raw
      );

      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      let currRisky = await this.contracts.risky.balanceOf(vault.address);
      let currStable = await this.contracts.stable.balanceOf(vault.address);
      let [success, , valueForPerformanceFee] =
        await vault.testCheckVaultSuccess({
          preVaultRisky: vaultState.lastLockedRisky,
          preVaultStable: vaultState.lastLockedStable,
          postVaultRisky: currRisky - vaultState.pendingRisky,
          postVaultStable: currStable,
        });
      expect(success).to.be.equal(true);
      expect(fromBn(valueForPerformanceFee)).to.be.not.equal("0");
    });
  });

  describe("Test internal vault fees computation", function () {
    beforeEach(async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();
    });
    it("First round should have no vault fees", async function () {
      let vaultState = await vault.vaultState();
      let currRisky = await this.contracts.risky.balanceOf(vault.address);
      let currStable = await this.contracts.stable.balanceOf(vault.address);
      let [feeInRisky, feeInStable] =
        await vault.testGetVaultFees({
          currRisky: currRisky,
          currStable: currStable,
          lastLockedRisky: vaultState.lastLockedRisky,
          lastLockedStable: vaultState.lastLockedStable,
          pendingRisky: vaultState.pendingRisky,
          managementFeePercent: 2000000,
          performanceFeePercent: 383561
        });
      expect(fromBn(feeInRisky, riskyDecimals)).to.be.equal("0");
      expect(fromBn(feeInStable, stableDecimals)).to.be.equal("0");
    });
    it("No vault fees without premium", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let vaultState = await vault.vaultState();
      let currRisky = await this.contracts.risky.balanceOf(vault.address);
      let currStable = await this.contracts.stable.balanceOf(vault.address);
      let [feeInRisky, feeInStable] =
        await vault.testGetVaultFees({
          currRisky: currRisky,
          currStable: currStable,
          lastLockedRisky: vaultState.lastLockedRisky,
          lastLockedStable: vaultState.lastLockedStable,
          pendingRisky: vaultState.pendingRisky,
          managementFeePercent: 2000000,
          performanceFeePercent: 383561
        });
      expect(fromBn(feeInRisky, riskyDecimals)).to.be.equal("0");
      expect(fromBn(feeInStable, stableDecimals)).to.be.equal("0");
    });
    it("No vault fees with deposit as pending", async function () {
      await vault
        .connect(this.wallets.alice)
        .deposit(toBn("1000", riskyDecimals));

      let vaultState = await vault.vaultState();
      let [feeInRisky, feeInStable] =
        await vault.testGetVaultFees({
          currRisky: await this.contracts.risky.balanceOf(vault.address),
          currStable: await this.contracts.stable.balanceOf(vault.address),
          lastLockedRisky: vaultState.lastLockedRisky,
          lastLockedStable: vaultState.lastLockedStable,
          pendingRisky: vaultState.pendingRisky,
          managementFeePercent: 2000000,
          performanceFeePercent: 383561
        });
      expect(fromBn(feeInRisky, riskyDecimals)).to.be.equal("0");
      expect(fromBn(feeInStable, stableDecimals)).to.be.equal("0");
    });
    it("Positive vault fees with premium", async function () {
      await vault.connect(this.wallets.keeper).deployVault();

      await this.contracts.risky.mint(
        vault.address,
        parseWei("10", riskyDecimals).raw
      );
      await this.contracts.stable.mint(
        vault.address,
        parseWei("10", stableDecimals).raw
      );

      let vaultState = await vault.vaultState();
      let [feeInRisky, feeInStable] =
        await vault.testGetVaultFees({
          currRisky: await this.contracts.risky.balanceOf(vault.address),
          currStable: await this.contracts.stable.balanceOf(vault.address),
          lastLockedRisky: vaultState.lastLockedRisky,
          lastLockedStable: vaultState.lastLockedStable,
          pendingRisky: vaultState.pendingRisky,
          managementFeePercent: 2000000,
          performanceFeePercent: 383561
        });
      expect(fromBnToFloat(feeInRisky, riskyDecimals)).to.be.greaterThan(0.2);
      expect(fromBnToFloat(feeInStable, stableDecimals)).to.be.greaterThan(0.2);
    });
  });

  describe("Test internal pool maturity computation", function () {
    it("Check computing next maturity", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let poolState = await vault.poolState();
      let maturity = await vault.testGetNextMaturity(poolState.currPoolId);

      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      poolState = await vault.poolState();
      expect(await vault.testGetPoolMaturity(poolState.currPoolId)).to.be.equal(
        maturity
      );
    });
    it("Check computing next friday", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let poolState = await vault.poolState();
      let currMaturity = await vault.testGetPoolMaturity(poolState.currPoolId);
      let maturity = await vault.testGetNextFriday(currMaturity);

      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      poolState = await vault.poolState();
      expect(await vault.testGetPoolMaturity(poolState.currPoolId)).to.be.equal(
        maturity
      );
    });
  });
});
