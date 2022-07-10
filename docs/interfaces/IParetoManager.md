---
description: IParetoManager
---

# IParetoManager.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/interfaces/IParetoManager.sol)

## Methods

### getNextGamma

Computes the gamma (or 1 - fee) for the next pool

```solidity title="Solidity"
function getNextGamma() external pure returns (uint32)
```

:::note Details
Currently hardcoded to 0.95. Choosing gamma effects the quality of replication
:::

#### Returns

| Name | Type   | Description                   |
| ---- | ------ | ----------------------------- |
| \_0  | uint32 | gamma Gamma for the next pool |

### getNextStrikePrice

Computes the strike price for the next pool by a multiple of the current price. Requires an oracle for spot price

```solidity title="Solidity"
function getNextStrikePrice() external view returns (uint128)
```

:::note Details
Uses the same decimals as the stable token
:::

#### Returns

| Name | Type    | Description                                   |
| ---- | ------- | --------------------------------------------- |
| \_0  | uint128 | strikePrice Relative price of risky in stable |

### getNextVolatility

Computes the volatility for the next pool

```solidity title="Solidity"
function getNextVolatility() external pure returns (uint32)
```

:::note Details
Currently hardcoded to 80%. Optimal choice is to match realized volatility in market
:::

#### Returns

| Name | Type   | Description                          |
| ---- | ------ | ------------------------------------ |
| \_0  | uint32 | sigma Estimate of implied volatility |

### getOracleDecimals

Return decimals used by the Chainlink Oracle

```solidity title="Solidity"
function getOracleDecimals() external view returns (uint8)
```

#### Returns

| Name | Type  | Description                                        |
| ---- | ----- | -------------------------------------------------- |
| \_0  | uint8 | decimals Oracle uses a precision of 10\*\*decimals |

### getPrice

Return both stable-to-risky and risky-to-stable prices

```solidity title="Solidity"
function getPrice() external view returns (uint256 stableToRiskyPrice, uint256 riskyToStablePrice)
```

#### Returns

| Name               | Type    | Description                                         |
| ------------------ | ------- | --------------------------------------------------- |
| stableToRiskyPrice | uint256 | Amount of risky tokens for one unit of stable token |
| riskyToStablePrice | uint256 | Amount of stable tokens for one unit of risky token |

### getRiskyPerLp

Computes the riskyForLp using oracle as spot price

```solidity title="Solidity"
function getRiskyPerLp(uint256 spot, uint128 strike, uint32 sigma, uint256 tau, uint8 riskyDecimals, uint8 stableDecimals) external view returns (uint256)
```

:::note Details
See page 14 of https://primitive.xyz/whitepaper-rmm-01.pdf. We cap the value within the range [0.1, 0.9]
:::

#### Parameters

| Name           | Type    | Description                                                                                   |
| -------------- | ------- | --------------------------------------------------------------------------------------------- |
| spot           | uint256 | Spot price in stable                                                                          |
| strike         | uint128 | Strike price in stable                                                                        |
| sigma          | uint32  | Implied volatility                                                                            |
| tau            | uint256 | Time to maturity in seconds. The conversion to years will happen within `MoreReplicationMath` |
| riskyDecimals  | uint8   | Decimals for the risky asset                                                                  |
| stableDecimals | uint8   | Decimals for the stable asset                                                                 |

#### Returns

| Name | Type    | Description                                |
| ---- | ------- | ------------------------------------------ |
| \_0  | uint256 | riskyForLp R1 variable (in risky decimals) |

### getRiskyToStablePrice

Price of one unit of risky token in stable using stable decimals

```solidity title="Solidity"
function getRiskyToStablePrice() external view returns (uint256)
```

:::note Details
Wrapper function around `_getOraclePrice`
:::

#### Returns

| Name | Type    | Description                                               |
| ---- | ------- | --------------------------------------------------------- |
| \_0  | uint256 | price Amount of stable tokens for one unit of risky token |

### getStablePerLp

Computes the exchange rate between stable asset and RMM-01 LP token. Assumes that `riskyPerLp` has been precomputed

```solidity title="Solidity"
function getStablePerLp(int128 invariantX64, uint256 riskyPerLp, uint128 strike, uint32 sigma, uint256 tau, uint8 riskyDecimals, uint8 stableDecimals) external pure returns (uint256)
```

#### Parameters

| Name           | Type    | Description                                   |
| -------------- | ------- | --------------------------------------------- |
| invariantX64   | int128  | Invariant for the pool                        |
| riskyPerLp     | uint256 | Amount of risky token to trade for 1 LP token |
| strike         | uint128 | Strike price in stable                        |
| sigma          | uint32  | Implied volatility                            |
| tau            | uint256 | Time to maturity in seconds                   |
| riskyDecimals  | uint8   | Decimals for the risky asset                  |
| stableDecimals | uint8   | Decimals for the stable asset                 |

#### Returns

| Name | Type    | Description                                                |
| ---- | ------- | ---------------------------------------------------------- |
| \_0  | uint256 | stableForLp Amount of stable token to trade for 1 LP token |

### getStableToRiskyPrice

Price of one unit of stable token in risky using risky decimals

```solidity title="Solidity"
function getStableToRiskyPrice() external view returns (uint256)
```

:::note Details
Wrapper function around `_getOraclePrice`
:::

#### Returns

| Name | Type    | Description                                               |
| ---- | ------- | --------------------------------------------------------- |
| \_0  | uint256 | price Amount of risky tokens for one unit of stable token |

### risky

Address for the risky asset

```solidity title="Solidity"
function risky() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### stable

Address for the stable asset

```solidity title="Solidity"
function stable() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### strikeMultiplier

Multiplier for strike selection as a percentage

```solidity title="Solidity"
function strikeMultiplier() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |
