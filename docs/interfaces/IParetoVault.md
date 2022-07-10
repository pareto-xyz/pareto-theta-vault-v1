---
description: IParetoVault
---

# IParetoVault.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/interfaces/IParetoVault.sol)

## Methods

### completeWithdraw

Users call this function to complete a requested withdraw from a past round. A withdrawal request must have been made via requestWithdraw. This function must be called after the round

```solidity title="Solidity"
function completeWithdraw() external nonpayable
```

:::note Details
Emits `WithdrawCompleteEvent`. Burns receipts, and transfers tokens to `msg.sender`
:::

### deposit

Deposits risky asset from `msg.sender` to the vault address. Updates the deposit receipt associated with `msg.sender` in rollover

```solidity title="Solidity"
function deposit(uint256 riskyAmount) external nonpayable
```

:::note Details
Emits `DepositEvent`
:::

#### Parameters

| Name        | Type    | Description                      |
| ----------- | ------- | -------------------------------- |
| riskyAmount | uint256 | Amount of risky asset to deposit |

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

Returns the balance held in the vault for one account in risky and stable tokens

```solidity title="Solidity"
function getAccountBalance(address account) external view returns (uint256 riskyAmount, uint256 stableAmount)
```

#### Parameters

| Name    | Type    | Description                   |
| ------- | ------- | ----------------------------- |
| account | address | Address to lookup balance for |

#### Returns

| Name         | Type    | Description                                  |
| ------------ | ------- | -------------------------------------------- |
| riskyAmount  | uint256 | Risky asset owned by the vault for the user  |
| stableAmount | uint256 | Stable asset owned by the vault for the user |

### keeper

Keeper who manually managers contract via deployment and rollover

```solidity title="Solidity"
function keeper() external view returns (address)
```

:::note Details
No access to critical vault changes
:::

#### Returns

| Name | Type    | Description           |
| ---- | ------- | --------------------- |
| \_0  | address | Address of the keeper |

### requestWithdraw

User requests a withdrawal that can be completed after the current round. Cannot request more shares than than the user obtained through deposits. Multiple requests can be made for the same round

```solidity title="Solidity"
function requestWithdraw(uint256 shares) external nonpayable
```

:::note Details
Emits `WithdrawRequestEvent`
:::

#### Parameters

| Name   | Type    | Description                  |
| ------ | ------- | ---------------------------- |
| shares | uint256 | Number of shares to withdraw |

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

Address of the `ParetoManager` contract to choose the next vault

```solidity title="Solidity"
function vaultManager() external view returns (address)
```

#### Returns

| Name | Type    | Description                           |
| ---- | ------- | ------------------------------------- |
| \_0  | address | Address of the ParetoManager contract |
