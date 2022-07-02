import { fromBn, toBn } from "evm-bn";

/**
 * @notice Compute the amounts of risky and stable assets to be locked
 *  Takes into account the fees
 * @param vaultRisky is the amount of risky token in the vault
 * @param vaultStable is the amount of stable token in the vault
 * @param lastLockedRisky is the amount of locked risky from last round
 * @param lastLockedStable is the amount of locked stable from last round
 * @param managementFeePerWeek is the management fee in percentage per week
 * @param performanceFee is the performance fee in percentage per week
 * @returns the amount of risky and stable token to be locked
 */
export function computeLockedAmounts(
  vaultRisky: number,
  vaultStable: number,
  lastLockedRisky: number,
  lastLockedStable: number,
  managementFeePerWeek: number,
  performanceFee: number,
): {
  lockedRisky: number,
  lockedStable: number,
  feeRisky: number,
  feeStable: number
} {
  let managementPercPerWeek = managementFeePerWeek / 100;
  let performancePerc = performanceFee / 100;

  let managementRisky =
    (vaultRisky - lastLockedRisky) * managementPercPerWeek;
  let performanceRisky = (vaultRisky - lastLockedRisky) * performancePerc;
  let feeRisky = managementRisky + performanceRisky;
  let managementStable =
    (vaultStable - lastLockedStable) * managementPercPerWeek;
  let performanceStable =
    (vaultStable - lastLockedStable) * performancePerc;
  let feeStable = managementStable + performanceStable;

  let lockedRisky = vaultRisky - feeRisky;
  let lockedStable = vaultStable - feeStable;

  return {
    lockedRisky: lockedRisky, 
    lockedStable: lockedStable,
    feeRisky: feeRisky,
    feeStable: feeStable,
  };
}

/**
 * @notice Helper function to go from BigNumber to float
 * @param value is the raw BigNumber object
 * @param decimals is the amount of decimals in the BigNumber
 * @returns the floating point value (through string casting)
 */
export function fromBnToFloat(
  value: any,
  decimals: number
): number {
  return parseFloat(fromBn(value, decimals));
}

/**
 * @notice Helper function to go from float to BigNumber
 * @param value is the float object
 * @param decimals is the amount of decimals in the BigNumber
 * @returns the BigNumber object
 */
 export function fromFloatToBn(
  value: number,
  decimals: number
): any {
  return toBn(value.toString(), decimals);
}