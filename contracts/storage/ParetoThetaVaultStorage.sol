// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

abstract contract ParetoThetaVaultStorageV1 {}

// We are following Ribbon's and Compound's method of upgrading new
// contract implementations. When we need to add new storage variables,
// we create a new version of `ParetoThetaVaultStorage`.
abstract contract ParetoThetaVaultStorage is ParetoThetaVaultStorageV1 {

}
