---
description: IParetoVault
---

# IParetoVault.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/interfaces/IParetoVault.sol)

## Methods

### completeWithdraw

Completes a requested withdraw from past round.

```solidity title="Solidity"
function completeWithdraw() external nonpayable
```

### deposit

Deposits risky asset from msg.sender.

```solidity title="Solidity"
function deposit(uint256 riskyAmount) external nonpayable
```

#### Parameters

| Name        | Type    | Description                             |
| ----------- | ------- | --------------------------------------- |
| riskyAmount | uint256 | is the amount of risky asset to deposit |

### feeRecipient

Recipient of the fees charged each rollover

```solidity title="Solidity"
function feeRecipient() external view returns (address)
```

#### Returns

| Name | Type    | Description                  |
| ---- | ------- | ---------------------------- |
| \_0  | address | Address of the fee recipient |

### getAccountBalance

Returns the asset balance held in the vault for one account

```solidity title="Solidity"
function getAccountBalance(address account) external view returns (uint256 riskyAmount, uint256 stableAmount)
```

#### Parameters

| Name    | Type    | Description                          |
| ------- | ------- | ------------------------------------ |
| account | address | is the address to lookup balance for |

#### Returns

| Name         | Type    | Description                                         |
| ------------ | ------- | --------------------------------------------------- |
| riskyAmount  | uint256 | is the risky asset owned by the vault for the user  |
| stableAmount | uint256 | is the stable asset owned by the vault for the user |

### keeper

Keeper who manually managers contract

```solidity title="Solidity"
function keeper() external view returns (address)
```

#### Returns

| Name | Type    | Description           |
| ---- | ------- | --------------------- |
| \_0  | address | Address of the keeper |

### requestWithdraw

Requests a withdraw that is processed after the current round

```solidity title="Solidity"
function requestWithdraw(uint256 shares) external nonpayable
```

#### Parameters

| Name   | Type    | Description                         |
| ------ | ------- | ----------------------------------- |
| shares | uint256 | is the number of shares to withdraw |

### risky

Risky token of the risky / stable pair

```solidity title="Solidity"
function risky() external view returns (address)
```

#### Returns

| Name | Type    | Description                         |
| ---- | ------- | ----------------------------------- |
| \_0  | address | Address of the risky token contract |

### stable

Stable token of the risky / stable pair

```solidity title="Solidity"
function stable() external view returns (address)
```

#### Returns

| Name | Type    | Description                          |
| ---- | ------- | ------------------------------------ |
| \_0  | address | Address of the stable token contract |

### vaultManager

ParetoManager contract used to specify options

```solidity title="Solidity"
function vaultManager() external view returns (address)
```

#### Returns

| Name | Type    | Description                           |
| ---- | ------- | ------------------------------------- |
| \_0  | address | Address of the ParetoManager contract |
