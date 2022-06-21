import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-tracer";
import "hardhat-dependency-compiler";

const chainIds = {
  ganache: 1337,
  hardhat: 31337,
};

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
        runs: 200,
        enabled: true,
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
      allowUnlimitedContractSize: true
    }
  }
};
