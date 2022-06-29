import hre, { ethers } from "hardhat";
import { Contract } from "ethers";
import { parseWei } from "web3-units";
import expect from "../shared/expect";
import { fromBn, toBn } from "evm-bn";

let vaultMath: Contract;

/**
 * @notice Borrowed from https://github.com/ribbon-finance/ribbon-v2/blob/master/test/libraries/ShareMath.ts
 */
describe("VaultMath contract", () => {
  beforeEach(async function () {
    const [deployer] = await hre.ethers.getSigners();
    const TestVaultMath = 
      await ethers.getContractFactory("TestVaultMath", deployer);
    vaultMath = await TestVaultMath.deploy()
  });
  describe("share to price conversions", function () {
    it("correct asset to share calculation", async function () {
      const decimals = 8;
      const underlyingAmount = toBn("1", decimals);
      const sharePrice = toBn("2", decimals);
      expect(
        fromBn(
          await vaultMath.assetToShare(underlyingAmount, sharePrice, decimals),
          decimals
        )
      ).to.be.equal("0.5");
    });
    it("correct share to asset calculation", async function () {
      const decimals = 8;
      const shares = toBn("1", decimals);
      const sharePrice = toBn("2", decimals);
      expect(
        fromBn(
          await vaultMath.shareToAsset(shares, sharePrice, decimals),
          decimals
        )
      ).to.be.equal("2");
    });
  });
});