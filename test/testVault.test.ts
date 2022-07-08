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
import { parse } from "path";

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
  describe("Test internal next pool preparation", function () {});
  describe("Test internal rollover preparation", function () {});
  describe("Test internal rebalancing", function () {});
  describe("Test internal optimal swap computation", function () {});
  describe("Test internal swapping", function () {});
  describe("Test internal vault success checking", function () {});
  describe("Test internal vault fees computation", function () {});
  describe("Test internal pool maturity computation", function () {});
});
