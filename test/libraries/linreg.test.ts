import hre, { ethers } from "hardhat";
import { Contract } from "ethers";
import expect from "../shared/expect";
import { fromBn, toBn } from "evm-bn";
import { fromBnToFloat } from "../../scripts/utils/testUtils";

let linearRegression: Contract;

describe("TestLinearRegression contract", () => {
  beforeEach(async function () {
    const [deployer] = await hre.ethers.getSigners();
    const TestLinearRegression = await ethers.getContractFactory(
      "TestLinearRegression",
      deployer
    );
    linearRegression = await TestLinearRegression.deploy();
  });
  describe("Check the prediction function", function () {
    it("Check one-dimensional with positive inputs and positive weights: test 1/3", async function () {
      let inputs = [toBn("1", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("1", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("1", 18).toString();
      let inputSigns = [true, true];
      let weightSigns = [true, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      expect(outputs.predSign).to.equal(true);
      expect(fromBn(outputs.pred, 18)).to.equal("2");
    });
    it("Check one-dimensional with positive inputs and positive weights: test 2/3", async function () {
      let inputs = [toBn("3.141", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("0.783", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("1.182", 18).toString();
      let inputSigns = [true, true];
      let weightSigns = [true, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = 3.141 * 0.783 + 1.182;
      expect(outputs.predSign).to.equal(true);
      expect(fromBnToFloat(outputs.pred, 18)).to.be.closeTo(answer, 1e-3);
    });
    it("Check one-dimensional with positive inputs and positive weights: test 3/3", async function () {
      let inputs = [toBn("0.998", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("8.214", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("4.444", 18).toString();
      let inputSigns = [true, true];
      let weightSigns = [true, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = 0.998 * 8.214 + 4.444;
      expect(outputs.predSign).to.equal(true);
      expect(fromBnToFloat(outputs.pred, 18)).to.be.closeTo(answer, 1e-3);
    });
    it("Check one-dimensional with positive inputs and negative weights: test 1/3", async function () {
      let inputs = [toBn("1", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("1", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("1", 18).toString();
      let inputSigns = [true, true];
      let weightSigns = [false, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      expect(outputs.predSign).to.equal(true);
      expect(fromBn(outputs.pred, 18)).to.equal("0");
    });
    it("Check one-dimensional with positive inputs and negative weights: test 2/3", async function () {
      let inputs = [toBn("3.141", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("0.783", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("1.182", 18).toString();
      let inputSigns = [true, true];
      let weightSigns = [false, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = 3.141 * -0.783 + 1.182;
      expect(outputs.predSign).to.equal(answer >= 0);
      expect(fromBnToFloat(outputs.pred, 18)).to.be.closeTo(
        Math.abs(answer),
        1e-3
      );
    });
    it("Check one-dimensional with positive inputs and negative weights: test 3/3", async function () {
      let inputs = [toBn("0.998", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("8.214", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("4.444", 18).toString();
      let inputSigns = [true, true];
      let weightSigns = [false, true];
      let biasSign = false;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = 0.998 * -8.214 - 4.444;
      expect(outputs.predSign).to.equal(answer >= 0);
      expect(fromBnToFloat(outputs.pred, 18)).to.be.closeTo(
        Math.abs(answer),
        1e-3
      );
    });
    it("Check one-dimensional with negative inputs and negative weights: test 1/3", async function () {
      let inputs = [toBn("1", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("1", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("1", 18).toString();
      let inputSigns = [false, true];
      let weightSigns = [false, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      expect(outputs.predSign).to.equal(true);
      expect(fromBn(outputs.pred, 18)).to.equal("2");
    });
    it("Check one-dimensional with negative inputs and negative weights: test 2/3", async function () {
      let inputs = [toBn("3.141", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("0.783", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("1.182", 18).toString();
      let inputSigns = [false, true];
      let weightSigns = [false, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = -3.141 * -0.783 + 1.182;
      expect(outputs.predSign).to.equal(answer >= 0);
      expect(fromBnToFloat(outputs.pred, 18)).to.be.closeTo(
        Math.abs(answer),
        1e-3
      );
    });
    it("Check one-dimensional with negative inputs and negative weights: test 3/3", async function () {
      let inputs = [toBn("0.998", 18).toString(), toBn("0", 18).toString()];
      let weights = [toBn("8.214", 18).toString(), toBn("0", 18).toString()];
      let bias = toBn("4.444", 18).toString();
      let inputSigns = [false, true];
      let weightSigns = [false, true];
      let biasSign = false;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = -0.998 * -8.214 - 4.444;
      expect(outputs.predSign).to.equal(answer >= 0);
      expect(fromBnToFloat(outputs.pred, 18)).to.be.closeTo(
        Math.abs(answer),
        1e-3
      );
    });
    it("Check two-dimensional computation: test 1/3", async function () {
      let inputs = [toBn("1", 18).toString(), toBn("1", 18).toString()];
      let weights = [toBn("1", 18).toString(), toBn("1", 18).toString()];
      let bias = toBn("1", 18).toString();
      let inputSigns = [true, true];
      let weightSigns = [true, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      expect(outputs.predSign).to.equal(true);
      expect(fromBn(outputs.pred, 18)).to.equal("3");
    });
    it("Check two-dimensional computation: test 2/3", async function () {
      let inputs = [toBn("3.141", 18).toString(), toBn("0.998", 18).toString()];
      let weights = [
        toBn("0.783", 18).toString(),
        toBn("8.214", 18).toString(),
      ];
      let bias = toBn("4.444", 18).toString();
      let inputSigns = [true, true];
      let weightSigns = [true, true];
      let biasSign = true;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = 3.141 * 0.783 + 0.998 * 8.214 + 4.444;
      expect(outputs.predSign).to.equal(answer >= 0);
      expect(fromBnToFloat(outputs.pred, 18)).to.be.closeTo(
        Math.abs(answer),
        1e-3
      );
    });
    it("Check two-dimensional computation: test 2/3", async function () {
      let inputs = [toBn("3.141", 18).toString(), toBn("0.998", 18).toString()];
      let weights = [
        toBn("0.783", 18).toString(),
        toBn("8.214", 18).toString(),
      ];
      let bias = toBn("4.444", 18).toString();
      let inputSigns = [true, false];
      let weightSigns = [false, true];
      let biasSign = false;
      let inputScaleFactor = 1;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = 3.141 * -0.783 - 0.998 * 8.214 - 4.444;
      expect(outputs.predSign).to.equal(answer >= 0);
      expect(fromBnToFloat(outputs.pred, 18)).to.be.closeTo(
        Math.abs(answer),
        1e-3
      );
    });
    it("Check prediction with smaller scale factor", async function () {
      let inputs = [toBn("3.141", 15).toString()];
      let weights = [toBn("0.783", 15).toString()];
      let bias = toBn("1.182", 15).toString();
      let inputSigns = [true];
      let weightSigns = [true];
      let biasSign = true;
      let inputScaleFactor = 10 ** 3;
      let weightScaleFactor = 10 ** 3;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = 3.141 * 0.783 + 1.182;
      expect(outputs.predSign).to.equal(true);
      expect(fromBnToFloat(outputs.pred, 15)).to.be.closeTo(answer, 1e-3);
    });
    it("Check prediction with different scale factors", async function () {
      let inputs = [toBn("3.141", 15).toString()];
      let weights = [toBn("0.783", 18).toString()];
      let bias = toBn("1.182", 18).toString();
      let inputSigns = [true];
      let weightSigns = [true];
      let biasSign = true;
      let inputScaleFactor = 10 ** 3;
      let weightScaleFactor = 1;
      let outputs = await linearRegression.predict(
        inputs,
        weights,
        bias,
        inputSigns,
        weightSigns,
        biasSign,
        inputScaleFactor,
        weightScaleFactor
      );
      let answer = 3.141 * 0.783 + 1.182;
      expect(outputs.predSign).to.equal(true);
      expect(fromBnToFloat(outputs.pred, 15)).to.be.closeTo(answer, 1e-3);
    });
  });
});
