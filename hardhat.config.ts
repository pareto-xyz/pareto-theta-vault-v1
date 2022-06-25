import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-tracer";
import "hardhat-dependency-compiler";

module.exports = {
  paths: {
    sources: "./contracts",
    cache: "./cache",
    tests: "./test",
    artifacts: "./artifacts"
  },
  solidity: {
    version: "0.8.6",
    settings: {
      optimizer: {
        runs: 1000,
        enabled: true
      },
    },
  },
  namedAccounts: {
    deployer: 0,
  },
  mocha: {
    timeout: 500000,
  },
  network: {
    hardhat: {
      blockGasLimit: 18e6,
      gas: 12e6,
      allowUnlimitedContractSize: true
    }
  }
};
