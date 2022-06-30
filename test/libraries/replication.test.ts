import hre, { ethers } from "hardhat";
import { Contract } from "ethers";
import expect from "../shared/expect";
import { normalCDF } from "../shared/utils";
import { fromBn, toBn } from "evm-bn";

let replicationMath: Contract;

describe("ReplicationMath contract", () => {
  beforeEach(async function () {
    const [deployer] = await hre.ethers.getSigners();
    const TestReplicationMath = await ethers.getContractFactory(
      "TestReplicationMath",
      deployer
    );
    replicationMath = await TestReplicationMath.deploy();
  });
  describe("directly calculate riskyPerLp", function () {
    it("correct computation of R1", async function () {
      // The spot is at price 1
      var strikes = [1.001, 1.01, 1.1, 0.999, 0.99, 0.9];
      var sigmas = [0.1, 0.3, 0.5, 0.7, 0.9];
      var tauInSeconds = [
        3600, // one hour
        86400, // one day
        604800, // one week
      ];

      let spot: string;
      let strike: string;
      let sigma: string;
      let r1: string;

      for (var i = 0; i < strikes.length; i++) {
        for (var j = 0; j < sigmas.length; j++) {
          for (var k = 0; k < tauInSeconds.length; k++) {
            spot = toBn("1", 18).toString();
            strike = toBn(strikes[i].toString(), 18).toString();
            sigma = toBn(sigmas[j].toString(), 4).toString();
            r1 = fromBn(
              await replicationMath.getRiskyPerLp(
                spot,
                strike,
                sigma,
                tauInSeconds[k],
                1,
                1
              ),
              18
            );

            let tau = tauInSeconds[k] / 31536000;
            let top = Math.log(1 / strikes[i]) + (tau * sigmas[j] ** 2) / 2;
            let bot = sigmas[j] * Math.sqrt(tau);
            let d1 = top / bot;
            let r2 = 1 - normalCDF(d1, 0, 1);

            /// @dev: 0.01 is a generous margin for error
            expect(parseFloat(r1)).to.be.closeTo(r2, 0.01);
          }
        }
      }
    });
  });
});
