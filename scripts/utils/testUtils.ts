/**
 * Utilities to check test performance. Contains implementations of solidity 
 * functions in javascript.
 */

import { Contract } from "ethers";
import { fromBn, toBn } from "evm-bn";

/**
 * @notice Compute expected performance and management fees
 * @param preVaultRisky is the amount of locked risky from last round
 * @param preVaultStable is the amount of locked stable from last round
 * @param postVaultRisky is the amount of risky token in the vault
 * @param postVaultStable is the amount of stable token in the vault
 * @param riskyToStablePrice is the price of a risky token in stable
 * @param managementFeePerWeek is the management fee in percentage per week
 * @param performanceFee is the performance fee in percentage per week
 */
export function getVaultFees(
  preVaultRisky: number,
  preVaultStable: number,
  postVaultRisky: number,
  postVaultStable: number,
  riskyToStablePrice: number,
  managementFeePerWeek: number,
  performanceFee: number,
): {
  vaultSuccess: boolean,
  feeRisky: number,
  feeStable: number
} {
  let stableToRiskyPrice = 1 / riskyToStablePrice;
  
  // Convert percentages to decimals
  let managementPercPerWeek = managementFeePerWeek / 100;
  let performancePerc = performanceFee / 100;

  // Check if there more risky tokens this round than last
  let moreRisky = postVaultRisky > (preVaultRisky + 1e-6);
  let moreStable = postVaultStable > (preVaultStable + 1e-6);

  let feeRisky: number = 0;
  let feeStable: number = 0;

  // If there are less of both, then clearly not a success
  if (!moreRisky && !moreStable) {
    return {
      vaultSuccess: false,
      feeRisky: 0,
      feeStable: 0,
    };
  }

  let preVaultValue: number;   // value of the vault before round
  let postVaultValue: number;  // value of the vault after round

  if (moreRisky) {
    preVaultValue = preVaultRisky + preVaultStable * stableToRiskyPrice;
    postVaultValue = postVaultRisky + postVaultStable * stableToRiskyPrice;
  } else { 
    preVaultValue = preVaultStable + preVaultRisky * riskyToStablePrice;
    postVaultValue = postVaultStable + postVaultRisky * riskyToStablePrice;
  }

  let vaultSuccess = postVaultValue > preVaultValue;
  let riskyForPerformanceFee = moreRisky;
  let valueForPerformanceFee = postVaultValue - preVaultValue;

  // Fees are only non-zero if vault succeeds
  if (vaultSuccess) {
    let managementRisky = postVaultRisky  * managementPercPerWeek;
    let managementStable = postVaultStable * managementPercPerWeek;
    
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

  return {
    vaultSuccess: vaultSuccess,
    feeRisky: feeRisky,
    feeStable: feeStable,
  }
}

/**
 * @notice Compute the amounts of risky and stable assets to be locked
 *         Takes into account the fees
 * @param vaultRisky is the amount of risky token in the vault
 * @param vaultStable is the amount of stable token in the vault
 * @param riskyToStablePrice is the price of a risky token in stable
 * @returns the amount of risky and stable token to be locked
 */
export function getLockedAmounts(
  vaultRisky: number,
  vaultStable: number,
  feeRisky: number,
  feeStable: number,
  riskyToStablePrice: number,
  riskyPerLp: number,
  stablePerLp: number,
): {
  lockedRisky: number,
  lockedStable: number,
} {
  // Ideally, we put everything outside of fees into the vault
  // We ignore withdrawal requests here
  let idealLockedRisky = vaultRisky - feeRisky;
  let idealLockedStable = vaultStable - feeStable;

  // Rebalance the quantities
  // Compute optimal swap ratios
  let [optimalRisky, optimalStable] = getBestSwap(
    idealLockedRisky, 
    idealLockedStable, 
    riskyPerLp, 
    stablePerLp, 
    riskyToStablePrice
  );

  let lockedRisky: number;
  let lockedStable: number;

  if (
    (idealLockedRisky >= optimalRisky) && (idealLockedStable >= optimalStable)
  ) {
    // If we have more of both assets, let's just put both in
    lockedRisky = idealLockedRisky;
    lockedStable = idealLockedStable;
  } else if (idealLockedRisky > optimalRisky) {
    // If we have more of one asset, then we assume we can get an optimal trade
    lockedRisky = optimalRisky;
    lockedStable = optimalStable;
  } else if (idealLockedStable > optimalStable) {
    lockedRisky = optimalRisky;
    lockedStable = optimalStable;
  }

  return {
    lockedRisky: lockedRisky, 
    lockedStable: lockedStable,
  };
}

export function getBestSwap(
  risky0: number,
  stable0: number,
  riskyPerLp: number,
  stablePerLp: number,
  riskyToStablePrice: number
): [number, number] {
  let value0 = riskyToStablePrice * risky0 + stable0;
  let denominator = riskyPerLp * riskyToStablePrice + stablePerLp;
  let risky1 = (riskyPerLp * value0) / denominator;
  let stable1 = (stablePerLp * value0) / denominator;
  return [risky1, stable1];
}

export async function getVaultBalance(
  risky: Contract,
  stable: Contract,
  vaultAddress: string,
  riskyDecimals: number,
  stableDecimals: number
): Promise<[number, number]> {
  let vaultRisky = fromBnToFloat(
    await risky.balanceOf(vaultAddress),
    riskyDecimals
  );
  let vaultStable = fromBnToFloat(
    await stable.balanceOf(vaultAddress),
    stableDecimals
  );
  return [vaultRisky, vaultStable]
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