---
description: IParetoManager
---

# IParetoManager.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/interfaces/IParetoManager.sol)

## Methods

### getNextGamma

Compute next fee for pool

```solidity title="Solidity"
function getNextGamma() external pure returns (uint32)
```

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | uint32 | undefined   |

### getNextStrikePrice

Compute next strike price using fixed multiplier

```solidity title="Solidity"
function getNextStrikePrice() external view returns (uint128)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint128 | undefined   |

### getNextVolatility

Compute next volatility using a constant for now

```solidity title="Solidity"
function getNextVolatility() external pure returns (uint32)
```

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | uint32 | undefined   |

### getOracleDecimals

Query oracle for its decimals

```solidity title="Solidity"
function getOracleDecimals() external view returns (uint8)
```

#### Returns

| Name | Type  | Description |
| ---- | ----- | ----------- |
| \_0  | uint8 | undefined   |

### getPrice

Query oracle for price of both stable to risky asset and the risky to stable asset

```solidity title="Solidity"
function getPrice() external view returns (uint256 stableToRiskyPrice, uint256 riskyToStablePrice)
```

#### Returns

| Name               | Type    | Description |
| ------------------ | ------- | ----------- |
| stableToRiskyPrice | uint256 | undefined   |
| riskyToStablePrice | uint256 | undefined   |

### getRiskyPerLp

Compute riskyForLp for RMM-01 pool creation

```solidity title="Solidity"
function getRiskyPerLp(uint256 spot, uint128 strike, uint32 sigma, uint256 tau, uint8 riskyDecimals, uint8 stableDecimals) external view returns (uint256)
```

#### Parameters

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| spot           | uint256 | undefined   |
| strike         | uint128 | undefined   |
| sigma          | uint32  | undefined   |
| tau            | uint256 | undefined   |
| riskyDecimals  | uint8   | undefined   |
| stableDecimals | uint8   | undefined   |

#### Returns

| Name | Type    | Description                                     |
| ---- | ------- | ----------------------------------------------- |
| \_0  | uint256 | Risky reserve per liquidity with risky decimals |

### getRiskyToStablePrice

Query oracle for price of risky to stable asset

```solidity title="Solidity"
function getRiskyToStablePrice() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### getStablePerLp

Compute stableForLp for RMM-01 pool creation

```solidity title="Solidity"
function getStablePerLp(int128 invariantX64, uint256 riskyPerLp, uint128 strike, uint32 sigma, uint256 tau, uint8 riskyDecimals, uint8 stableDecimals) external pure returns (uint256)
```

#### Parameters

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| invariantX64   | int128  | undefined   |
| riskyPerLp     | uint256 | undefined   |
| strike         | uint128 | undefined   |
| sigma          | uint32  | undefined   |
| tau            | uint256 | undefined   |
| riskyDecimals  | uint8   | undefined   |
| stableDecimals | uint8   | undefined   |

#### Returns

| Name | Type    | Description                                       |
| ---- | ------- | ------------------------------------------------- |
| \_0  | uint256 | Stable reserve per liquidity with stable decimals |

### getStableToRiskyPrice

Query oracle for price of stable to risky asset

```solidity title="Solidity"
function getStableToRiskyPrice() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### risky

Risky token of the risky / stable pair

```solidity title="Solidity"
function risky() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### stable

Stable token of the risky / stable pair

```solidity title="Solidity"
function stable() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### strikeMultiplier

Multiplier for strike price (2 decimal places)

```solidity title="Solidity"
function strikeMultiplier() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |
