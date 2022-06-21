const ParetoThetaVault = artifacts.require("ParetoThetaVault");
const ParetoManager = artifacts.require("ParetoManager");

const PRIMITIVE_MANAGER = "0xca931d8EeE3ccdcA7FdC4bD4c7A089BfB6948B15";

module.exports = function(deployer) {
  deployer.deploy(ParetoThetaVault);
  deployer.deploy(ParetoManager, '');
};