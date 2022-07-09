---
description: ParetoManager
---

# ParetoManager.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/managers/ParetoManager.sol)

Automated management of Pareto Theta VaultsDecides strike prices by percentages

## Methods

### chainlinkOracle

Address for the ChainLink oracle Network: Kovan USDC-ETH: 0x64EaC61A2DFda2c3Fa04eED49AA33D021AeC8838 Network: Rinkeby USDC-ETH: 0xdCA36F27cbC4E38aE16C4E9f99D39b42337F6dcf Network: MainNet USDC-ETH: 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4

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

#### Returns

| Name  | Type   | Description                    |
| ----- | ------ | ------------------------------ |
| gamma | uint32 | is the Gamma for the next pool |

### getNextStrikePrice

Computes the strike price for the next pool by multiplying the current price - requires an oracle

```solidity title="Solidity"
function getNextStrikePrice() external view returns (uint128 strikePrice)
```

:::note Details
Uses the same decimals as the stable token
:::

#### Returns

| Name        | Type    | Description                              |
| ----------- | ------- | ---------------------------------------- |
| strikePrice | uint128 | is the relative price of risky in stable |

### getNextVolatility

Computes the volatility for the next pool

```solidity title="Solidity"
function getNextVolatility() external pure returns (uint32 sigma)
```

#### Returns

| Name  | Type   | Description                        |
| ----- | ------ | ---------------------------------- |
| sigma | uint32 | is the implied volatility estimate |

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

Helper function to return both stable-to-risky and risky-to-stable prices

```solidity title="Solidity"
function getPrice() external view returns (uint256 stableToRiskyPrice, uint256 riskyToStablePrice)
```

#### Returns

| Name               | Type    | Description |
| ------------------ | ------- | ----------- |
| stableToRiskyPrice | uint256 | undefined   |
| riskyToStablePrice | uint256 | undefined   |

### getRiskyPerLp

Computes the riskyForLp using oracle as spot price Wrapper around MoreReplicationMath

```solidity title="Solidity"
function getRiskyPerLp(uint256 spot, uint128 strike, uint32 sigma, uint256 tau, uint8 riskyDecimals, uint8 stableDecimals) external pure returns (uint256 riskyForLp)
```

:::note Details
See page 14 of https://primitive.xyz/whitepaper-rmm-01.pdfThresholds the value to acceptable changes
:::

#### Parameters

| Name           | Type    | Description                                                                                     |
| -------------- | ------- | ----------------------------------------------------------------------------------------------- |
| spot           | uint256 | is the spot price in stable                                                                     |
| strike         | uint128 | is the strike price in stable                                                                   |
| sigma          | uint32  | is the implied volatility                                                                       |
| tau            | uint256 | is time to maturity in seconds The conversion to years will happen within `MoreReplicationMath` |
| riskyDecimals  | uint8   | is the decimals for the risky asset                                                             |
| stableDecimals | uint8   | is the decimals for the stable asset                                                            |

#### Returns

| Name       | Type    | Description                            |
| ---------- | ------- | -------------------------------------- |
| riskyForLp | uint256 | is the R1 variable (in risky decimals) |

### getRiskyToStablePrice

Query oracle for price of risky to stable asset

```solidity title="Solidity"
function getRiskyToStablePrice() external view returns (uint256 price)
```

#### Returns

| Name  | Type    | Description |
| ----- | ------- | ----------- |
| price | uint256 | undefined   |

### getStablePerLp

Computes the stablePerLp assuming riskyPerLp is known Wrapper around MoreReplicationMath

```solidity title="Solidity"
function getStablePerLp(int128 invariantX64, uint256 riskyPerLp, uint128 strike, uint32 sigma, uint256 tau, uint8 riskyDecimals, uint8 stableDecimals) external pure returns (uint256 stableForLp)
```

#### Parameters

| Name           | Type    | Description                                      |
| -------------- | ------- | ------------------------------------------------ |
| invariantX64   | int128  | is the invariant currently for the pool          |
| riskyPerLp     | uint256 | is amount of risky token to trade for 1 LP token |
| strike         | uint128 | is the strike price in stable                    |
| sigma          | uint32  | is the implied volatility                        |
| tau            | uint256 | is time to maturity in seconds                   |
| riskyDecimals  | uint8   | is the decimals for the risky asset              |
| stableDecimals | uint8   | is the decimals for the stable asset             |

#### Returns

| Name        | Type    | Description                                       |
| ----------- | ------- | ------------------------------------------------- |
| stableForLp | uint256 | is amount of stable token to trade for 1 LP token |

### getStableToRiskyPrice

Query oracle for price of stable to risky asset

```solidity title="Solidity"
function getStableToRiskyPrice() external view returns (uint256 price)
```

#### Returns

| Name  | Type    | Description |
| ----- | ------- | ----------- |
| price | uint256 | undefined   |

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

Risky token of the risky / stable pair

```solidity title="Solidity"
function risky() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### riskyFirst

```solidity title="Solidity"
function riskyFirst() external view returns (bool)
```

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |

### setStrikeMultiplier

Set the multiplier for setting the strike price

```solidity title="Solidity"
function setStrikeMultiplier(uint256 _strikeMultiplier) external nonpayable
```

#### Parameters

| Name               | Type    | Description                             |
| ------------------ | ------- | --------------------------------------- |
| \_strikeMultiplier | uint256 | is the strike multiplier (decimals = 2) |

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
