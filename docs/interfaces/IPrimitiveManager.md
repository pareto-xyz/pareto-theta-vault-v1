---
description: Interface of PrimitiveManager contract
---

# IPrimitiveManager.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/interfaces/IPrimitiveManager.sol)

:::note Details
Taken from https://raw.githubusercontent.com/primitivefinance/rmm-managerEdited to contain the Withdraw event and withdrawal function
:::

## Methods

### allocate

Allocates liquidity into a pool

```solidity title="Solidity"
function allocate(address recipient, bytes32 poolId, address risky, address stable, uint256 delRisky, uint256 delStable, bool fromMargin, uint256 minLiquidityOut) external payable returns (uint256 delLiquidity)
```

#### Parameters

| Name            | Type    | Description                                                      |
| --------------- | ------- | ---------------------------------------------------------------- |
| recipient       | address | Address that receives minted ERC-1155 Primitive liquidity tokens |
| poolId          | bytes32 | Id of the pool                                                   |
| risky           | address | Address of the risky asset                                       |
| stable          | address | Address of the stable asset                                      |
| delRisky        | uint256 | Amount of risky tokens to allocate                               |
| delStable       | uint256 | Amount of stable tokens to allocate                              |
| fromMargin      | bool    | True if the funds of the sender should be used                   |
| minLiquidityOut | uint256 | undefined                                                        |

#### Returns

| Name         | Type    | Description                                 |
| ------------ | ------- | ------------------------------------------- |
| delLiquidity | uint256 | Amount of liquidity allocated into the pool |

### allocateCallback

Triggered when providing liquidity to an Engine

```solidity title="Solidity"
function allocateCallback(uint256 delRisky, uint256 delStable, bytes data) external nonpayable
```

#### Parameters

| Name      | Type    | Description                                                   |
| --------- | ------- | ------------------------------------------------------------- |
| delRisky  | uint256 | Amount of risky tokens required to provide to risky reserve   |
| delStable | uint256 | Amount of stable tokens required to provide to stable reserve |
| data      | bytes   | Calldata passed on allocate function call                     |

### create

Creates a new pool using the specified parameters

```solidity title="Solidity"
function create(address risky, address stable, uint128 strike, uint32 sigma, uint32 maturity, uint32 gamma, uint256 riskyPerLp, uint256 delLiquidity) external payable returns (bytes32 poolId, uint256 delRisky, uint256 delStable)
```

#### Parameters

| Name         | Type    | Description                                                                                                                        |
| ------------ | ------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| risky        | address | Address of the risky asset                                                                                                         |
| stable       | address | Address of the stable asset                                                                                                        |
| strike       | uint128 | Strike price of the pool to calibrate to, with the same decimals as the stable token                                               |
| sigma        | uint32  | Volatility to calibrate to as an unsigned 256-bit integer w/ precision of 1e4, 10000 = 100%                                        |
| maturity     | uint32  | Maturity timestamp of the pool, in seconds                                                                                         |
| gamma        | uint32  | Multiplied against swap in amounts to apply fee, equal to 1 - fee %, an unsigned 32-bit integer, w/ precision of 1e4, 10000 = 100% |
| riskyPerLp   | uint256 | Risky reserve per liq. with risky decimals, = 1 - N(d1), d1 = (ln(S/K)+(r*sigma^2/2))/sigma*sqrt(tau)                              |
| delLiquidity | uint256 | Amount of liquidity to allocate to the curve, wei value with 18 decimals of precision                                              |

#### Returns

| Name      | Type    | Description                                                                                   |
| --------- | ------- | --------------------------------------------------------------------------------------------- |
| poolId    | bytes32 | Id of the new created pool (Keccak256 hash of the engine address, maturity, sigma and strike) |
| delRisky  | uint256 | Amount of risky tokens allocated into the pool                                                |
| delStable | uint256 | Amount of stable tokens allocated into the pool                                               |

### createCallback

Triggered when creating a new pool for an Engine

```solidity title="Solidity"
function createCallback(uint256 delRisky, uint256 delStable, bytes data) external nonpayable
```

#### Parameters

| Name      | Type    | Description                                                   |
| --------- | ------- | ------------------------------------------------------------- |
| delRisky  | uint256 | Amount of risky tokens required to initialize risky reserve   |
| delStable | uint256 | Amount of stable tokens required to initialize stable reserve |
| data      | bytes   | Calldata passed on create function call                       |

### remove

Removes liquidity from a pool

```solidity title="Solidity"
function remove(address engine, bytes32 poolId, uint256 delLiquidity, uint256 minRiskyOut, uint256 minStableOut) external nonpayable returns (uint256 delRisky, uint256 delStable)
```

#### Parameters

| Name         | Type    | Description                                             |
| ------------ | ------- | ------------------------------------------------------- |
| engine       | address | Address of the engine                                   |
| poolId       | bytes32 | Id of the pool                                          |
| delLiquidity | uint256 | Amount of liquidity to remove                           |
| minRiskyOut  | uint256 | Minimum amount of risky tokens expected to be received  |
| minStableOut | uint256 | Minimum amount of stable tokens expected to be received |

#### Returns

| Name      | Type    | Description                                   |
| --------- | ------- | --------------------------------------------- |
| delRisky  | uint256 | Amount of risky tokens removed from the pool  |
| delStable | uint256 | Amount of stable tokens removed from the pool |

### withdraw

Withdraws funds from the margin of a Primitive Engine

```solidity title="Solidity"
function withdraw(address recipient, address engine, uint256 delRisky, uint256 delStable) external nonpayable
```

#### Parameters

| Name      | Type    | Description                                 |
| --------- | ------- | ------------------------------------------- |
| recipient | address | Address receiving the funds in their wallet |
| engine    | address | Primitive Engine to withdraw from           |
| delRisky  | uint256 | Amount of risky token to withdraw           |
| delStable | uint256 | Amount of stable token to withdraw          |

## Events

### Allocate

Emitted when liquidity is allocated

```solidity title="Solidity"
event Allocate(address payer, address indexed recipient, address indexed engine, bytes32 indexed poolId, uint256 delLiquidity, uint256 delRisky, uint256 delStable, bool fromMargin)
```

#### Parameters

| Name                | Type    | Description                                                      |
| ------------------- | ------- | ---------------------------------------------------------------- |
| payer               | address | Payer sending liquidity                                          |
| recipient `indexed` | address | Address that receives minted ERC-1155 Primitive liquidity tokens |
| engine `indexed`    | address | Primitive Engine receiving liquidity                             |
| poolId `indexed`    | bytes32 | Id of the pool receiving liquidity                               |
| delLiquidity        | uint256 | Amount of liquidity allocated                                    |
| delRisky            | uint256 | Amount of risky tokens allocated                                 |
| delStable           | uint256 | Amount of stable tokens allocated                                |
| fromMargin          | bool    | True if liquidity was paid from margin                           |

### Create

Emitted when a new pool is created

```solidity title="Solidity"
event Create(address indexed payer, address indexed engine, bytes32 indexed poolId, uint128 strike, uint32 sigma, uint32 maturity, uint32 gamma, uint256 delLiquidity)
```

#### Parameters

| Name             | Type    | Description                                                 |
| ---------------- | ------- | ----------------------------------------------------------- |
| payer `indexed`  | address | Payer sending liquidity                                     |
| engine `indexed` | address | Primitive Engine where the pool is created                  |
| poolId `indexed` | bytes32 | Id of the new pool                                          |
| strike           | uint128 | Strike of the new pool                                      |
| sigma            | uint32  | Sigma of the new pool                                       |
| maturity         | uint32  | Maturity of the new pool                                    |
| gamma            | uint32  | Gamma of the new pool                                       |
| delLiquidity     | uint256 | Amount of liquidity allocated (minus the minimum liquidity) |

### Remove

Emitted when liquidity is removed

```solidity title="Solidity"
event Remove(address indexed payer, address indexed engine, bytes32 indexed poolId, uint256 delLiquidity, uint256 delRisky, uint256 delStable)
```

#### Parameters

| Name             | Type    | Description                                    |
| ---------------- | ------- | ---------------------------------------------- |
| payer `indexed`  | address | Payer receiving liquidity                      |
| engine `indexed` | address | Engine where liquidity is removed from         |
| poolId `indexed` | bytes32 | Id of the pool where liquidity is removed from |
| delLiquidity     | uint256 | Amount of liquidity removed                    |
| delRisky         | uint256 | Amount of risky tokens allocated               |
| delStable        | uint256 | Amount of stable tokens allocated              |

### Withdraw

Emitted when funds are withdrawn

```solidity title="Solidity"
event Withdraw(address indexed payer, address indexed recipient, address indexed engine, address risky, address stable, uint256 delRisky, uint256 delStable)
```

#### Parameters

| Name                | Type    | Description                                 |
| ------------------- | ------- | ------------------------------------------- |
| payer `indexed`     | address | Address withdrawing the funds               |
| recipient `indexed` | address | Address receiving the funds in their wallet |
| engine `indexed`    | address | Engine where the funds are withdrawn from   |
| risky               | address | Address of the risky token                  |
| stable              | address | Address of the stable token                 |
| delRisky            | uint256 | Amount of withdrawn risky                   |
| delStable           | uint256 | Amount of withdrawn stable                  |

## Errors

### MinLiquidityOutError

Thrown when the received liquidity is lower than the expected

```solidity title="Solidity"
error MinLiquidityOutError()
```

### MinRemoveOutError

Thrown when the received risky / stable amounts are lower than the expected

```solidity title="Solidity"
error MinRemoveOutError()
```

### ZeroLiquidityError

Thrown when trying to add or remove zero liquidity

```solidity title="Solidity"
error ZeroLiquidityError()
```
