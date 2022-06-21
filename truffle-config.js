module.exports = {
  contracts_directory: "./contracts",
  contracts_build_directory: "./build/contracts",
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: 5777,
    },
  },
  compilers: {
    solc: {
      version: "=0.8.6",
    },
  },
  plugins: ["truffle-contract-size"],
};
