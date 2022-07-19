import hre, { ethers } from "hardhat";
import { Contract } from "ethers";
import expect from "../shared/expect";
import { normalCDF } from "../shared/utils";
import { fromBn, toBn } from "evm-bn";
import { fromBnToFloat, ppf } from "../../scripts/utils/testUtils";

let moreReplicationMath: Contract;

describe("MoreReplicationMath contract", () => {
  beforeEach(async function () {
    const [deployer] = await hre.ethers.getSigners();
    const TestMoreReplicationMath = await ethers.getContractFactory(
      "TestMoreReplicationMath",
      deployer
    );
    moreReplicationMath = await TestMoreReplicationMath.deploy();
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
              await moreReplicationMath.getRiskyPerLp(
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
    it("single example riskyPerLp", async function () {
      let spot = 1;
      let strike = 1.1;
      let sigma = 0.8;

      let r1 = fromBn(
        await moreReplicationMath.getRiskyPerLp(
          toBn(spot.toString(), 18).toString(),
          toBn(strike.toString(), 18).toString(),
          toBn(sigma.toString(), 4).toString(),
          1656662400,
          1,
          1
        ),
        18
      );

      let tau = 18280;
      let top = Math.log(spot / strike) + (tau * sigma ** 2) / 2;
      let bot = sigma * Math.sqrt(tau);
      let d1 = top / bot;
      let r2 = 1 - normalCDF(d1, 0, 1);

      expect(parseFloat(r1)).to.be.closeTo(r2, 0.01);
    });
  });
  it("correct computation of S1", async function () {
    // The spot is at price 1
    var strikes = [1.001, 1.01, 0.999, 0.99];
    var sigmas = [0.3, 0.5, 0.7, 0.9];
    var tauInSeconds = [
      3600, // one hour
      86400, // one day
      604800, // one week
    ];
    let invariant = 0;
    let spot: string;
    let strike: string;
    let sigma: string;
    let r1: string;
    let s1: string;

    for (var i = 0; i < strikes.length; i++) {
      for (var j = 0; j < sigmas.length; j++) {
        for (var k = 0; k < tauInSeconds.length; k++) {
          spot = toBn("1", 18).toString();
          strike = toBn(strikes[i].toString(), 18).toString();
          sigma = toBn(sigmas[j].toString(), 4).toString();
          r1 = fromBn(
            await moreReplicationMath.getRiskyPerLp(
              spot,
              strike,
              sigma,
              tauInSeconds[k],
              1,
              1
            ),
            18
          );
          s1 = fromBn(
            await moreReplicationMath.getStablePerLp(
              invariant,
              toBn(r1, 18).toString(),
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

          let s2 = strikes[i] * normalCDF(ppf(1 - r2) - bot, 0, 1) + invariant;

          /// @dev: 0.01 is a generous margin for error
          expect(parseFloat(r1)).to.be.closeTo(r2, 0.01);
          expect(parseFloat(s1)).to.be.closeTo(s2, 0.01);
        }
      }
    }
  });
  it("correct computation of strike given delta", async function () {
    var spot = 1500;
    var deltas = [0.1, 0.3, 0.5, 0.7, 0.9];
    var sigmas = [0.1, 0.3, 0.5, 0.7, 0.9];
    var tauInSeconds = [
      3600, // one hour
      86400, // one day
      604800, // one week
    ];
    let strike: number;
    for (var i = 0; i < deltas.length; i++) {
      for (var j = 0; j < sigmas.length; j++) {
        for (var k = 0; k < tauInSeconds.length; k++) {
          strike = fromBnToFloat(
            await moreReplicationMath.getStrikeGivenDelta(
              toBn(deltas[i].toString(), 4).toString(),
              toBn(spot.toString(), 18).toString(),
              toBn(sigmas[j].toString(), 4).toString(),
              tauInSeconds[k],
              1
            ),
            18
          );
          let tau = tauInSeconds[k] / 31536000;
          let one = (tau * sigmas[j] ** 2) / 2;
          let two = sigmas[j] * Math.sqrt(tau);
          let strike2 = spot * Math.exp(one - two * ppf(deltas[i]));

          expect(strike).to.be.closeTo(strike2, 1);
        }
      }
    }
  });
});
