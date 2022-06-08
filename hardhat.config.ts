require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  paths: {
    sources: "./contracts",
    cache: "./cache",
    tests: "./test",
  },
  solidity: {
    version: "0.8.4",
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
