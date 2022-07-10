---
description: ParetoManager
---

# ParetoManager.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/managers/ParetoManager.sol)

Automated management of Pareto Theta Vaults. Decides strike prices, volatility, and gamma through heuristics

## Methods

### chainlinkOracle

Address for the ChainLink oracle

```solidity title="Solidity"
function chainlinkOracle() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### getNextGamma

Computes the gamma (or 1 - fee) for the next pool

```solidity title="Solidity"
function getNextGamma() external pure returns (uint32 gamma)
```

:::note Details
Currently hardcoded to 0.95. Choosing gamma effects the quality of replication
:::

#### Returns

| Name  | Type   | Description             |
| ----- | ------ | ----------------------- |
| gamma | uint32 | Gamma for the next pool |

### getNextStrikePrice

Computes the strike price for the next pool by a multiple of the current price. Requires an oracle for spot price

```solidity title="Solidity"
function getNextStrikePrice() external view returns (uint128 strikePrice)
```

:::note Details
Uses the same decimals as the stable token
:::

#### Returns

| Name        | Type    | Description                       |
| ----------- | ------- | --------------------------------- |
| strikePrice | uint128 | Relative price of risky in stable |

### getNextVolatility

Computes the volatility for the next pool

```solidity title="Solidity"
function getNextVolatility() external pure returns (uint32 sigma)
```

:::note Details
Currently hardcoded to 80%. Optimal choice is to match realized volatility in market
:::

#### Returns

| Name  | Type   | Description                    |
| ----- | ------ | ------------------------------ |
| sigma | uint32 | Estimate of implied volatility |

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
function getRiskyPerLp(uint256 spot, uint128 strike, uint32 sigma, uint256 tau, uint8 riskyDecimals, uint8 stableDecimals) external pure returns (uint256 riskyForLp)
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

| Name       | Type    | Description                     |
| ---------- | ------- | ------------------------------- |
| riskyForLp | uint256 | R1 variable (in risky decimals) |

### getRiskyToStablePrice

Price of one unit of risky token in stable using stable decimals

```solidity title="Solidity"
function getRiskyToStablePrice() external view returns (uint256 price)
```

:::note Details
Wrapper function around `_getOraclePrice`
:::

#### Returns

| Name  | Type    | Description                                         |
| ----- | ------- | --------------------------------------------------- |
| price | uint256 | Amount of stable tokens for one unit of risky token |

### getStablePerLp

Computes the exchange rate between stable asset and RMM-01 LP token. Assumes that `riskyPerLp` has been precomputed

```solidity title="Solidity"
function getStablePerLp(int128 invariantX64, uint256 riskyPerLp, uint128 strike, uint32 sigma, uint256 tau, uint8 riskyDecimals, uint8 stableDecimals) external pure returns (uint256 stableForLp)
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

| Name        | Type    | Description                                    |
| ----------- | ------- | ---------------------------------------------- |
| stableForLp | uint256 | Amount of stable token to trade for 1 LP token |

### getStableToRiskyPrice

Price of one unit of stable token in risky using risky decimals

```solidity title="Solidity"
function getStableToRiskyPrice() external view returns (uint256 price)
```

:::note Details
Wrapper function around `_getOraclePrice`
:::

#### Returns

| Name  | Type    | Description                                         |
| ----- | ------- | --------------------------------------------------- |
| price | uint256 | Amount of risky tokens for one unit of stable token |

### owner

```solidity title="Solidity"
function owner() external view returns (address)
```

:::note Details
Returns the address of the current owner.
:::

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### renounceOwnership

```solidity title="Solidity"
function renounceOwnership() external nonpayable
```

:::note Details
Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.
:::

### risky

Address for the risky asset

```solidity title="Solidity"
function risky() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### riskyFirst

True if the oracle returns risky in terms of stable. False if oracle returns stable in terms of risky

```solidity title="Solidity"
function riskyFirst() external view returns (bool)
```

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |

### setStrikeMultiplier

Set the multiplier for deciding strike price

```solidity title="Solidity"
function setStrikeMultiplier(uint256 _strikeMultiplier) external nonpayable
```

#### Parameters

| Name               | Type    | Description                      |
| ------------------ | ------- | -------------------------------- |
| \_strikeMultiplier | uint256 | Strike multiplier (decimals = 2) |

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

### transferOwnership

```solidity title="Solidity"
function transferOwnership(address newOwner) external nonpayable
```

:::note Details
Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.
:::

#### Parameters

| Name     | Type    | Description |
| -------- | ------- | ----------- |
| newOwner | address | undefined   |

## Events

### OwnershipTransferred

```solidity title="Solidity"
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```

#### Parameters

| Name                    | Type    | Description |
| ----------------------- | ------- | ----------- |
| previousOwner `indexed` | address | undefined   |
| newOwner `indexed`      | address | undefined   |

## Errors

### InverseOutOfBounds

Thrown on passing an arg that is out of the input range for these math functions

```solidity title="Solidity"
error InverseOutOfBounds(int128 value)
```

#### Parameters

| Name  | Type   | Description |
| ----- | ------ | ----------- |
| value | int128 | undefined   |
