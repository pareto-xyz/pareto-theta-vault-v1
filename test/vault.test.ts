import hre from "hardhat";
import { constants, Contract } from "ethers";
import { parseWei } from "web3-units";
import { runTest } from "./shared/fixture";
import expect from "./shared/expect";

let vault: Contract;
let poolId: string;

runTest("vault", function() {
  beforeEach(async function() {
    const vault = await hre.ethers.getContractFactory("ParetoVault");
    await vault.deploy(this.contracts.primitiveManager.address);
  });
});