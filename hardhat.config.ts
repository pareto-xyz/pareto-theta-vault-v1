import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-tracer";
import "hardhat-dependency-compiler";
import "@primitivefi/hardhat-dodoc";
import "solidity-coverage";

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
        enabled: true
      },
    },
  },
  dodoc: {
    debugMode: false,
    runOnCompile: false,
    templatePath: './docusaurus.sqrl',
    outputDir: 'docs',
    exclude: ['efi', 'elin', 'k', 'libraries', 'test', 'console'],
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
