import { utils, BigNumber } from "ethers";
import { erf } from "mathjs";

export function computePoolId(
  engine: string,
  maturity: string | number,
  sigma: string | BigNumber,
  strike: string | BigNumber,
  gamma: string | BigNumber
): string {
  return utils.keccak256(
    utils.solidityPack(
      ["address", "uint128", "uint32", "uint32", "uint32"],
      [engine, strike, sigma, maturity, gamma]
    )
  );
}

/**
 * @notice Statically computes an Engine address.
 * @param factory Deployer of the Engine contract.
 * @param risky Risky token address.
 * @param stable Stable token address.
 * @param bytecode Bytecode of the PrimitiveEngine.sol smart contract.
 * @returns engine address.
 */
export function computeEngineAddress(
  factory: string,
  risky: string,
  stable: string,
  bytecode: string
): string {
  const salt = utils.solidityKeccak256(
    ["bytes"],
    [utils.defaultAbiCoder.encode(["address", "address"], [risky, stable])]
  );
  return utils.getCreate2Address(factory, salt, utils.keccak256(bytecode));
}

export function normalCDF(x: number, mean: number, sigma: number): number {
  return (1 - erf((mean - x) / (Math.sqrt(2) * sigma))) / 2;
}
