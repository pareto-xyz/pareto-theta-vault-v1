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
    it("check deposit receipt updated", async function () {
      let receipt = await vault.depositReceipts(this.wallets.alice.address);
      expect(receipt.round).to.be.equal(1);
      expect(fromBn(receipt.riskyToDeposit, riskyDecimals)).to.be.equal("1.2");
      // User should have no owned shares from previous rounds
      expect(fromBn(receipt.ownedShares, shareDecimals)).to.be.equal("0");
    });
    it("check pending risky updated", async function () {
      let vaultState = await vault.vaultState();
      expect(fromBn(vaultState.pendingRisky, riskyDecimals)).to.be.equal("1.2");
    });
    it("check shares increase after rollover", async function () {
      await vault.connect(this.wallets.keeper).deployVault();
      await vault.connect(this.wallets.keeper).rollover();

      let riskyAmount = parseWei("2", riskyDecimals).raw;
      let creditor = this.wallets.alice.address;
      await vault.testProcessDeposit(riskyAmount, creditor);
      let receipt = await vault.depositReceipts(this.wallets.alice.address);

      // In this next round, we no longer expect Alice to own zero shares
      expect(receipt.round).to.be.equal(2);
      expect(fromBn(receipt.riskyToDeposit, riskyDecimals)).to.be.equal("2");
      expect(fromBnToFloat(receipt.ownedShares, shareDecimals)).to.be.greaterThan(0);
    });
  });
  describe("Test internal deposit of liquidity into RMM pool", function () {});
  describe("Test internal withdrawal request", function () {});
  describe("Test internal withdrawal completion", function () {});
  describe("Test internal withdrawal of liquidity from RMM pool", function () {});
  describe("Test internal next pool preparation", function () {});
  describe("Test internal rollover preparation", function () {});
  describe("Test internal rebalancing", function () {});
  describe("Test internal optimal swap computation", function () {});
  describe("Test internal swapping", function () {});
  describe("Test internal vault success checking", function () {});
  describe("Test internal vault fees computation", function () {});
  describe("Test internal pool maturity computation", function () {});
});
