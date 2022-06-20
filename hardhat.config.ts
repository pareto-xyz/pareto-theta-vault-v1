import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
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
  mocha: {
    timeout: 500000,
  },
};
