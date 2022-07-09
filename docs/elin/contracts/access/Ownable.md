---
description: Ownable
---

# Ownable.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contractselin/contracts/access/Ownable.sol)

:::note Details
Contract module which provides a basic access control mechanism, where there is an account (an owner) that can be granted exclusive access to specific functions. By default, the owner account will be the one that deploys the contract. This can later be changed with {transferOwnership}. This module is used through inheritance. It will make available the modifier `onlyOwner`, which can be applied to your functions to restrict their use to the owner.
:::

## Methods

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