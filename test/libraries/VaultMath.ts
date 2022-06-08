import { ethers } from "hardhat";
import { Contract } from "ethers";
import { assert } from "../utils/assertions"
import { parseUnits } from "ethers/lib/utils";

let vaultMath: Contract;

describe("VaultMath", () => {
  // Deploy `TestVaultMath` contract to local network
  before(async() => {
    const TestVaultMath = await ethers.getContractFactory("TestVaultMath");
    vaultMath = await TestVaultMath.deploy();
  });

  // Test `TestVaultMath.assetToShares`
  describe("#assetToShares", () => {
    it("converts assets to shares", async () => {
      const decimals = 8;
      const assets = parseUnits("1", decimals);
      const sharePrice = parseUnits("2", decimals);

      assert.bnEqual(
        await vaultMath.assetToShares(assets, sharePrice, decimals),
        parseUnits("0.5", decimals);
      );
    });
  });

  // Test `TestVaultMath.sharesToAsset`
  describe("#sharesToAsset", () => {
    it("converts shares to assets", async () => {
      const decimals = 8;
      const shares = parseUnits("1", decimals);
      const sharePrice = parseUnits("2", decimals);

      assert.bnEqual(
        await vaultMath.sharesToAsset(shares, sharePrice, decimals),
        parseUnits("2", decimals)
      );
    });
  });
});
