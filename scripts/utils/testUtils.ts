import { fromBn, toBn } from "evm-bn";

/**
 * @notice Compute the amounts of risky and stable assets to be locked
 *  Takes into account the fees
 * @param vaultRisky is the amount of risky token in the vault
 * @param vaultStable is the amount of stable token in the vault
 * @param stableToRiskyPrice is the price of a stable token in risky
 * @param lastLockedRisky is the amount of locked risky from last round
 * @param lastLockedStable is the amount of locked stable from last round
 * @param managementFeePerWeek is the management fee in percentage per week
 * @param performanceFee is the performance fee in percentage per week
 * @returns the amount of risky and stable token to be locked
 */
export function computeLockedAmounts(
  vaultRisky: number,
  vaultStable: number,
  stableToRiskyPrice: number,
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
  let riskyToStablePrice = 1 / stableToRiskyPrice;
  let managementPercPerWeek = managementFeePerWeek / 100;
  let performancePerc = performanceFee / 100;

  let moreRisky = vaultRisky > lastLockedRisky;
  let moreStable = vaultStable > lastLockedStable;

  let feeRisky: number = 0;
  let feeStable: number = 0;

  if (!moreRisky && !moreStable) {
    return {
      lockedRisky: vaultRisky, 
      lockedStable: vaultStable,
      feeRisky: feeRisky,
      feeStable: feeStable,
    };
  }
  
  let preVaultValue: number;
  let postVaultValue: number;

  if (moreRisky) {
    preVaultValue = lastLockedRisky + lastLockedStable * stableToRiskyPrice;
    postVaultValue = vaultRisky + vaultStable * stableToRiskyPrice;
  } else { 
    preVaultValue = lastLockedStable + lastLockedRisky * riskyToStablePrice;
    postVaultValue = vaultStable + vaultRisky * riskyToStablePrice;
  }

  let vaultSuccess = postVaultValue > preVaultValue;
  let riskyForPerformanceFee = moreRisky;
  let valueForPerformanceFee = postVaultValue - preVaultValue;

  if (vaultSuccess) {
    let managementRisky = vaultRisky  * managementPercPerWeek;
    let managementStable = vaultStable * managementPercPerWeek;
    
    let performanceRisky: number = 0;
    let performanceStable: number = 0;

    if (riskyForPerformanceFee) {
      performanceRisky = valueForPerformanceFee * performancePerc;
    } else {
      performanceStable = valueForPerformanceFee * performancePerc;
    }
    
    feeRisky = managementRisky + performanceRisky;
    feeStable = managementStable + performanceStable;
  }

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