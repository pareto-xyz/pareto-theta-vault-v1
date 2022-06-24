import hre from "hardhat";
import { constants, Contract } from "ethers";
import { parseWei } from "web3-units";
import { runTest } from "./shared/fixture";
import expect from "./shared/expect";
import { DEFAULT_CALIBRATION } from "./shared/config";

let paretoVault: Contract;
let poolId: string;

runTest('paretoVault', function() {
  beforeEach(async function() {
    const ParetoVault = 
      await hre.ethers.getContractFactory('ParetoVault');
    
      paretoVault = await ParetoVault.deploy(
        this.contracts.primitiveManager.address
      );
  });
});