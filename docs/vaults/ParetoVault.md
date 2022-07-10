---
description: ParetoVault
---

# ParetoVault.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/vaults/ParetoVault.sol)

Based on Ribbon&#39;s implementation of Theta Vaults.

:::note Details
Many of the functions are written to preserve the design of RibbonVault.sol. See https://docs.ribbon.finance/developers/ribbon-v2.
:::

## Methods

### MIN_LIQUIDITY

This constant specifies the minimum amount of liquidity that the Pareto RTV must hold. This amount is used to create Primitive RMM-01 pools.

```solidity title="Solidity"
function MIN_LIQUIDITY() external view returns (uint256)
```

:::note Details
In extracting fees and withdrawal, the contract must maintain this minimum
:::

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### TOKEN_NAME

Name of the Pareto token that acts as a receipt for users who deposit.

```solidity title="Solidity"
function TOKEN_NAME() external view returns (string)
```

:::note Details
Currently, this token is not transferred to users
:::

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | string | undefined   |

### TOKEN_SYMBOL

Symbol of the Pareto token that acts as a receipt for users who deposit

```solidity title="Solidity"
function TOKEN_SYMBOL() external view returns (string)
```

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | string | undefined   |

### allowance

```solidity title="Solidity"
function allowance(address owner, address spender) external view returns (uint256)
```

:::note Details
See {IERC20-allowance}.
:::

#### Parameters

| Name    | Type    | Description |
| ------- | ------- | ----------- |
| owner   | address | undefined   |
| spender | address | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### approve

```solidity title="Solidity"
function approve(address spender, uint256 amount) external nonpayable returns (bool)
```

:::note Details
See {IERC20-approve}. NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on `transferFrom`. This is semantically equivalent to an infinite approval. Requirements: - `spender` cannot be the zero address.
:::

#### Parameters

| Name    | Type    | Description |
| ------- | ------- | ----------- |
| spender | address | undefined   |
| amount  | uint256 | undefined   |

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |

### balanceOf

```solidity title="Solidity"
function balanceOf(address account) external view returns (uint256)
```

:::note Details
See {IERC20-balanceOf}.
:::

#### Parameters

| Name    | Type    | Description |
| ------- | ------- | ----------- |
| account | address | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### completeWithdraw

Users call this function to complete a requested withdraw from a past round. A withdrawal request must have been made via requestWithdraw. This function must be called after the round

```solidity title="Solidity"
function completeWithdraw() external nonpayable
```

:::note Details
Emits `WithdrawCompleteEvent`. Burns receipts, and transfers tokens to `msg.sender`
:::

### decimals

```solidity title="Solidity"
function decimals() external view returns (uint8)
```

:::note Details
Returns the number of decimals used to get its user representation. For example, if `decimals` equals `2`, a balance of `505` tokens should be displayed to a user as `5.05` (`505 / 10 ** 2`). Tokens usually opt for a value of 18, imitating the relationship between Ether and Wei. This is the value {ERC20} uses, unless this function is overridden; NOTE: This information is only used for _display_ purposes: it in no way affects any of the arithmetic of the contract, including {IERC20-balanceOf} and {IERC20-transfer}.
:::

#### Returns

| Name | Type  | Description |
| ---- | ----- | ----------- |
| \_0  | uint8 | undefined   |

### decreaseAllowance

```solidity title="Solidity"
function decreaseAllowance(address spender, uint256 subtractedValue) external nonpayable returns (bool)
```

:::note Details
Atomically decreases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address. - `spender` must have allowance for the caller of at least `subtractedValue`.
:::

#### Parameters

| Name            | Type    | Description |
| --------------- | ------- | ----------- |
| spender         | address | undefined   |
| subtractedValue | uint256 | undefined   |

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |

### deployVault

Deploys a new vault, which creates a new Primitive RMM-01 pool. Calls the `ParetoManager` to choose the parameters of the next vault

```solidity title="Solidity"
function deployVault() external nonpayable
```

:::note Details
Emits `DeployVaultEvent`. This is the first function to be called when starting a new vault round
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

### depositReceipts

A map from address to a Vault.DepositReceipt, which tracks the round, the amount of risky to deposit, and the amount of shares owned by the user

```solidity title="Solidity"
function depositReceipts(address) external view returns (uint16 round, uint104 riskyToDeposit, uint128 ownedShares)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

#### Returns

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| round          | uint16  | undefined   |
| riskyToDeposit | uint104 | undefined   |
| ownedShares    | uint128 | undefined   |

### feeRecipient

Recipient of the fees charged each rollover

```solidity title="Solidity"
function feeRecipient() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

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

### getAccountShares

Returns the number of shares owned by one account

```solidity title="Solidity"
function getAccountShares(address account) external view returns (uint256 shares)
```

#### Parameters

| Name    | Type    | Description                   |
| ------- | ------- | ----------------------------- |
| account | address | Address to lookup balance for |

#### Returns

| Name   | Type    | Description                               |
| ------ | ------- | ----------------------------------------- |
| shares | uint256 | Balance for the account in share decimals |

### increaseAllowance

```solidity title="Solidity"
function increaseAllowance(address spender, uint256 addedValue) external nonpayable returns (bool)
```

:::note Details
Atomically increases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address.
:::

#### Parameters

| Name       | Type    | Description |
| ---------- | ------- | ----------- |
| spender    | address | undefined   |
| addedValue | uint256 | undefined   |

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |

### initRounds

Save gas by writing default values into the `roundSharePriceInRisky/Stable`. Future writes will be no longer be cold writes

```solidity title="Solidity"
function initRounds(uint256 numRounds) external nonpayable
```

:::note Details
Writing 1 makes subsequent writes warm, reducing the gas from 20k to 5k
:::

#### Parameters

| Name      | Type    | Description                               |
| --------- | ------- | ----------------------------------------- |
| numRounds | uint256 | Number of rounds to initialize in the map |

### keeper

Keeper who manually managers contract via deployment and rollover.

```solidity title="Solidity"
function keeper() external view returns (address)
```

:::note Details
No access to critical vault changes
:::

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### managementFee

Fee to take yearly, set to 2 percent of owned asset value. Fees are transferred in fractions weekly, only taken if the vault makes profit.

```solidity title="Solidity"
function managementFee() external view returns (uint256)
```

:::note Details
Specified in decimals of 6.
:::

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### managerState

The keeper can manually specify strike price, volatility, gamma.

```solidity title="Solidity"
function managerState() external view returns (uint128 manualStrike, uint16 manualStrikeRound, uint32 manualVolatility, uint16 manualVolatilityRound, uint32 manualGamma, uint16 manualGammaRound)
```

:::note Details
The manageState saves these choices for use in `_prepareNextPool`
:::

#### Returns

| Name                  | Type    | Description |
| --------------------- | ------- | ----------- |
| manualStrike          | uint128 | undefined   |
| manualStrikeRound     | uint16  | undefined   |
| manualVolatility      | uint32  | undefined   |
| manualVolatilityRound | uint16  | undefined   |
| manualGamma           | uint32  | undefined   |
| manualGammaRound      | uint16  | undefined   |

### name

```solidity title="Solidity"
function name() external view returns (string)
```

:::note Details
Returns the name of the token.
:::

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | string | undefined   |

### onERC1155BatchReceived

```solidity title="Solidity"
function onERC1155BatchReceived(address, address, uint256[], uint256[], bytes) external nonpayable returns (bytes4)
```

#### Parameters

| Name | Type      | Description |
| ---- | --------- | ----------- |
| \_0  | address   | undefined   |
| \_1  | address   | undefined   |
| \_2  | uint256[] | undefined   |
| \_3  | uint256[] | undefined   |
| \_4  | bytes     | undefined   |

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | bytes4 | undefined   |

### onERC1155Received

```solidity title="Solidity"
function onERC1155Received(address, address, uint256, uint256, bytes) external nonpayable returns (bytes4)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |
| \_1  | address | undefined   |
| \_2  | uint256 | undefined   |
| \_3  | uint256 | undefined   |
| \_4  | bytes   | undefined   |

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | bytes4 | undefined   |

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

### pendingWithdraw

Map from user address to a `Vault.PendingWithdraw` object, which stores the round of withdrawal and the amount of shares to withdraw

```solidity title="Solidity"
function pendingWithdraw(address) external view returns (uint16 round, uint128 shares)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

#### Returns

| Name   | Type    | Description |
| ------ | ------- | ----------- |
| round  | uint16  | undefined   |
| shares | uint128 | undefined   |

### performanceFee

Fee to take weekly, set to 20 percent of vault profits. Only taken if the vault makes profit that week.

```solidity title="Solidity"
function performanceFee() external view returns (uint256)
```

:::note Details
Specified in decimals of 6.
:::

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### poolState

Tracks the state of RMM-01 pool, including pool identifiers and parameters

```solidity title="Solidity"
function poolState() external view returns (bytes32 nextPoolId, bytes32 currPoolId, uint256 currLiquidity, struct Vault.PoolParams currPoolParams, struct Vault.PoolParams nextPoolParams, uint32 nextPoolReadyAt)
```

#### Returns

| Name            | Type             | Description |
| --------------- | ---------------- | ----------- |
| nextPoolId      | bytes32          | undefined   |
| currPoolId      | bytes32          | undefined   |
| currLiquidity   | uint256          | undefined   |
| currPoolParams  | Vault.PoolParams | undefined   |
| nextPoolParams  | Vault.PoolParams | undefined   |
| nextPoolReadyAt | uint32           | undefined   |

### primitiveParams

Stores information on the Primitive contracts

```solidity title="Solidity"
function primitiveParams() external view returns (address manager, address engine, address factory, uint8 decimals)
```

#### Returns

| Name     | Type    | Description |
| -------- | ------- | ----------- |
| manager  | address | undefined   |
| engine   | address | undefined   |
| factory  | address | undefined   |
| decimals | uint8   | undefined   |

### renounceOwnership

```solidity title="Solidity"
function renounceOwnership() external nonpayable
```

:::note Details
Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.
:::

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

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### rollover

Rolls the vault&#39;s funds into the next vault, pays royalties to the keeper, performs rebalancing, and deposits tokens into a new Primitive pool

```solidity title="Solidity"
function rollover() external nonpayable
```

:::note Details
Pending assets get converted into locked assets. The round is complete after this call, at which the round is incremented
:::

### roundSharePriceInRisky

Maps user address to a price in risky decimals

```solidity title="Solidity"
function roundSharePriceInRisky(uint256) external view returns (uint256)
```

:::note Details
Since users may withdraw shares deposited from an arbitrarily early round, share prices in risky token across all rounds are saved.
:::

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### roundSharePriceInStable

Maps user address to a price in stable decimals

```solidity title="Solidity"
function roundSharePriceInStable(uint256) external view returns (uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### seedVault

Seeds vault with minimum funding for RMM-01 pool deployment. Called only by owner

```solidity title="Solidity"
function seedVault() external nonpayable
```

:::note Details
Requires approval by owner to contract of at least MIN_LIQUIDITY. This is used to satisfy the minimum liquidity to start RMM-01 pools
:::

### setFeeRecipient

Sets the address of the fee recipient

```solidity title="Solidity"
function setFeeRecipient(address newFeeRecipient) external nonpayable
```

:::note Details
Must be a number between 0 and 1 in decimals of 4. Set only by the owner
:::

#### Parameters

| Name            | Type    | Description                      |
| --------------- | ------- | -------------------------------- |
| newFeeRecipient | address | Address of the new fee recipient |

### setGamma

Sets the gamma for the next vault

```solidity title="Solidity"
function setGamma(uint32 gamma) external nonpayable
```

:::note Details
Set only by the owner
:::

#### Parameters

| Name  | Type   | Description                            |
| ----- | ------ | -------------------------------------- |
| gamma | uint32 | One minus fee for the next RMM-01 pool |

### setKeeper

Sets the address of the keeper

```solidity title="Solidity"
function setKeeper(address newKeeper) external nonpayable
```

:::note Details
Set only by the owner
:::

#### Parameters

| Name      | Type    | Description               |
| --------- | ------- | ------------------------- |
| newKeeper | address | Address of the new keeper |

### setManagementFee

Sets the address for a ParetoManager contract

```solidity title="Solidity"
function setManagementFee(uint256 newManagementFee) external nonpayable
```

:::note Details
Set only by the owner
:::

#### Parameters

| Name             | Type    | Description                         |
| ---------------- | ------- | ----------------------------------- |
| newManagementFee | uint256 | Address of the new manager contract |

### setPerformanceFee

Sets the performance fee for the vault

```solidity title="Solidity"
function setPerformanceFee(uint256 newPerformanceFee) external nonpayable
```

#### Parameters

| Name              | Type    | Description             |
| ----------------- | ------- | ----------------------- |
| newPerformanceFee | uint256 | The new performance fee |

### setStrikePrice

Sets the strike price for the next vault

```solidity title="Solidity"
function setStrikePrice(uint128 strikePrice) external nonpayable
```

:::note Details
Set only by the owner
:::

#### Parameters

| Name        | Type    | Description                          |
| ----------- | ------- | ------------------------------------ |
| strikePrice | uint128 | Strike price of the next RMM-01 pool |

### setUniswapPoolFee

Sets the fee to search for when routing a Uniswap trade

```solidity title="Solidity"
function setUniswapPoolFee(uint24 newPoolFee) external nonpayable
```

:::note Details
Set only by the owner
:::

#### Parameters

| Name       | Type   | Description                                                                |
| ---------- | ------ | -------------------------------------------------------------------------- |
| newPoolFee | uint24 | Pool fee of the Uniswap AMM used to route swaps of risky and stable tokens |

### setVaultManager

Sets the new Vault Manager contract

```solidity title="Solidity"
function setVaultManager(address newVaultManager) external nonpayable
```

#### Parameters

| Name            | Type    | Description                         |
| --------------- | ------- | ----------------------------------- |
| newVaultManager | address | Address of the new manager contract |

### setVolatility

Sets the implied volatility for the next vault

```solidity title="Solidity"
function setVolatility(uint32 volatility) external nonpayable
```

:::note Details
Must be a number between 0 and 1 in decimals of 4. Set only by the owner
:::

#### Parameters

| Name       | Type   | Description                                |
| ---------- | ------ | ------------------------------------------ |
| volatility | uint32 | Implied volatility of the next RMM-01 pool |

### stable

Stable token of the risky / stable pair

```solidity title="Solidity"
function stable() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### supportsInterface

```solidity title="Solidity"
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```

:::note Details
See {IERC165-supportsInterface}.
:::

#### Parameters

| Name        | Type   | Description |
| ----------- | ------ | ----------- |
| interfaceId | bytes4 | undefined   |

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |

### symbol

```solidity title="Solidity"
function symbol() external view returns (string)
```

:::note Details
Returns the symbol of the token, usually a shorter version of the name.
:::

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | string | undefined   |

### tokenParams

Stores the addresses and decimals for risky and stable tokens

```solidity title="Solidity"
function tokenParams() external view returns (address risky, address stable, uint8 riskyDecimals, uint8 stableDecimals)
```

#### Returns

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| risky          | address | undefined   |
| stable         | address | undefined   |
| riskyDecimals  | uint8   | undefined   |
| stableDecimals | uint8   | undefined   |

### totalRisky

Returns vault&#39;s balance of risky assets, including amounts locked in pools

```solidity title="Solidity"
function totalRisky() external view returns (uint256)
```

#### Returns

| Name | Type    | Description                                                     |
| ---- | ------- | --------------------------------------------------------------- |
| \_0  | uint256 | riskyAmount Amount of risky asset used or owned by the contract |

### totalStable

Returns vault&#39;s balance of stable assets, including amounts locked in pools

```solidity title="Solidity"
function totalStable() external view returns (uint256)
```

#### Returns

| Name | Type    | Description                                                       |
| ---- | ------- | ----------------------------------------------------------------- |
| \_0  | uint256 | stableAmount Amount of stable asset used or owned by the contract |

### totalSupply

```solidity title="Solidity"
function totalSupply() external view returns (uint256)
```

:::note Details
See {IERC20-totalSupply}.
:::

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### transfer

```solidity title="Solidity"
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```

:::note Details
See {IERC20-transfer}. Requirements: - `to` cannot be the zero address. - the caller must have a balance of at least `amount`.
:::

#### Parameters

| Name   | Type    | Description |
| ------ | ------- | ----------- |
| to     | address | undefined   |
| amount | uint256 | undefined   |

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |

### transferFrom

```solidity title="Solidity"
function transferFrom(address from, address to, uint256 amount) external nonpayable returns (bool)
```

:::note Details
See {IERC20-transferFrom}. Emits an {Approval} event indicating the updated allowance. This is not required by the EIP. See the note at the beginning of {ERC20}. NOTE: Does not update the allowance if the current allowance is the maximum `uint256`. Requirements: - `from` and `to` cannot be the zero address. - `from` must have a balance of at least `amount`. - the caller must have allowance for `from`&#39;s tokens of at least `amount`.
:::

#### Parameters

| Name   | Type    | Description |
| ------ | ------- | ----------- |
| from   | address | undefined   |
| to     | address | undefined   |
| amount | uint256 | undefined   |

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |

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

### uniswapParams

Stores the Uniswap router, including the contract address and pool fee

```solidity title="Solidity"
function uniswapParams() external view returns (address router, uint24 poolFee)
```

#### Returns

| Name    | Type    | Description |
| ------- | ------- | ----------- |
| router  | address | undefined   |
| poolFee | uint24  | undefined   |

### vaultManager

Address of the `ParetoManager` contract to choose the next vault

```solidity title="Solidity"
function vaultManager() external view returns (address)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### vaultState

Stores information on the risky and stable assets that enter and exit the vault&#39;s lifecycle

```solidity title="Solidity"
function vaultState() external view returns (uint16 round, uint104 lockedRisky, uint104 lockedStable, uint104 lastLockedRisky, uint104 lastLockedStable, uint128 pendingRisky, uint256 lastQueuedWithdrawRisky, uint256 lastQueuedWithdrawStable, uint256 currQueuedWithdrawShares, uint256 totalQueuedWithdrawShares)
```

:::note Details
Includes the amount of tokens locked in a RMM-01 pool, the amount of tokens pending from recent deposits, and the amount of tokens queued for withdrawal
:::

#### Returns

| Name                      | Type    | Description |
| ------------------------- | ------- | ----------- |
| round                     | uint16  | undefined   |
| lockedRisky               | uint104 | undefined   |
| lockedStable              | uint104 | undefined   |
| lastLockedRisky           | uint104 | undefined   |
| lastLockedStable          | uint104 | undefined   |
| pendingRisky              | uint128 | undefined   |
| lastQueuedWithdrawRisky   | uint256 | undefined   |
| lastQueuedWithdrawStable  | uint256 | undefined   |
| currQueuedWithdrawShares  | uint256 | undefined   |
| totalQueuedWithdrawShares | uint256 | undefined   |

## Events

### Approval

```solidity title="Solidity"
event Approval(address indexed owner, address indexed spender, uint256 value)
```

#### Parameters

| Name              | Type    | Description |
| ----------------- | ------- | ----------- |
| owner `indexed`   | address | undefined   |
| spender `indexed` | address | undefined   |
| value             | uint256 | undefined   |

### ClosePositionEvent

Emitted when keeper removes liquidity from the previous vault

```solidity title="Solidity"
event ClosePositionEvent(bytes32 poolId, uint256 burnLiquidity, uint256 riskyAmount, uint256 stableAmount, address indexed keeper)
```

#### Parameters

| Name             | Type    | Description                                 |
| ---------------- | ------- | ------------------------------------------- |
| poolId           | bytes32 | Identifier for the pool                     |
| burnLiquidity    | uint256 | Amount of liquidity from RMM-01 to burn     |
| riskyAmount      | uint256 | Amount of risky assets withdrawn from pool  |
| stableAmount     | uint256 | Amount of stable assets withdrawn from pool |
| keeper `indexed` | address | Address of the keeper                       |

### DeployVaultEvent

Emitted when keeper deploys a new vault

```solidity title="Solidity"
event DeployVaultEvent(bytes32 poolId, uint128 strikePrice, uint32 volatility, uint32 gamma, address indexed keeper)
```

#### Parameters

| Name             | Type    | Description                            |
| ---------------- | ------- | -------------------------------------- |
| poolId           | bytes32 | Identifier for the pool                |
| strikePrice      | uint128 | Strike price in stable asset           |
| volatility       | uint32  | Implied volatility in decimals of four |
| gamma            | uint32  | One minus fees in decimals of four     |
| keeper `indexed` | address | Address of the keeper                  |

### DepositEvent

Emitted when any user deposits risky asset into vault. Users cannot deposit stable assets

```solidity title="Solidity"
event DepositEvent(address indexed account, uint256 riskyAmount, uint16 round)
```

#### Parameters

| Name              | Type    | Description                           |
| ----------------- | ------- | ------------------------------------- |
| account `indexed` | address | Address of the depositor              |
| riskyAmount       | uint256 | Amount of risky token to be deposited |
| round             | uint16  | Current round                         |

### FeeRecipientSetEvent

Emitted when owner sets new recipient address for fees

```solidity title="Solidity"
event FeeRecipientSetEvent(address indexed keeper)
```

#### Parameters

| Name             | Type    | Description           |
| ---------------- | ------- | --------------------- |
| keeper `indexed` | address | Address of the keeper |

### GammaSetEvent

Emitted when keeper manually sets next round&#39;s trading fee

```solidity title="Solidity"
event GammaSetEvent(uint32 gamma, uint16 round)
```

#### Parameters

| Name  | Type   | Description               |
| ----- | ------ | ------------------------- |
| gamma | uint32 | 1-fee in decimals of four |
| round | uint16 | Current round             |

### KeeperSetEvent

Emitted when owner sets new keeper address

```solidity title="Solidity"
event KeeperSetEvent(address indexed keeper)
```

#### Parameters

| Name             | Type    | Description           |
| ---------------- | ------- | --------------------- |
| keeper `indexed` | address | Address of the keeper |

### ManagementFeeSetEvent

Emitted when owner sets new yearly management fee in 6 decimals

```solidity title="Solidity"
event ManagementFeeSetEvent(uint256 managementFee, uint256 newManagementFee)
```

#### Parameters

| Name             | Type    | Description                             |
| ---------------- | ------- | --------------------------------------- |
| managementFee    | uint256 | Current management fee in decimals of 4 |
| newManagementFee | uint256 | New management fee in decimals of 4     |

### OpenPositionEvent

Emitted when keeper deposits vault assets into RMM-01 pool during rollover

```solidity title="Solidity"
event OpenPositionEvent(bytes32 poolId, uint256 riskyAmount, uint256 stableAmount, uint256 returnLiquidity, address indexed keeper)
```

#### Parameters

| Name             | Type    | Description                                                           |
| ---------------- | ------- | --------------------------------------------------------------------- |
| poolId           | bytes32 | Identifier for the pool                                               |
| riskyAmount      | uint256 | Amount of risky token deposited into RMM-01 pool                      |
| stableAmount     | uint256 | Amount of stable token deposited into RMM-01 pool                     |
| returnLiquidity  | uint256 | Amount of liquidity returned from RMM-01 pool in exchange for deposit |
| keeper `indexed` | address | Address of the keeper                                                 |

### OwnershipTransferred

```solidity title="Solidity"
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```

#### Parameters

| Name                    | Type    | Description |
| ----------------------- | ------- | ----------- |
| previousOwner `indexed` | address | undefined   |
| newOwner `indexed`      | address | undefined   |

### PerformanceFeeSetEvent

Emitted when owner sets new weekly performance fee in 6 decimals

```solidity title="Solidity"
event PerformanceFeeSetEvent(uint256 performanceFee, uint256 newPerformanceFee)
```

#### Parameters

| Name              | Type    | Description                              |
| ----------------- | ------- | ---------------------------------------- |
| performanceFee    | uint256 | Current performance fee in decimals of 4 |
| newPerformanceFee | uint256 | New performance fee in decimals of 4     |

### RebalanceVaultEvent

Emitted in rollover when assets are rebalanced before being deposited in pool

```solidity title="Solidity"
event RebalanceVaultEvent(uint256 initialRisky, uint256 initialStable, uint256 optimalRisky, uint256 optimalStable, address indexed keeper)
```

#### Parameters

| Name             | Type    | Description                                      |
| ---------------- | ------- | ------------------------------------------------ |
| initialRisky     | uint256 | Initial amounts of risky token pre-rebalancing   |
| initialStable    | uint256 | Initial amounts of stable token pre-rebalancing  |
| optimalRisky     | uint256 | Optimal amounts of risky token post-rebalancing  |
| optimalStable    | uint256 | Optimal amounts of stable token post-rebalancing |
| keeper `indexed` | address | Address of the keeper                            |

### StrikePriceSetEvent

Emitted when keeper manually sets next round&#39;s strike price in stable decimals

```solidity title="Solidity"
event StrikePriceSetEvent(uint128 strikePrice, uint16 round)
```

#### Parameters

| Name        | Type    | Description                                 |
| ----------- | ------- | ------------------------------------------- |
| strikePrice | uint128 | Next strike price in terms of stable assets |
| round       | uint16  | Current round                               |

### Transfer

```solidity title="Solidity"
event Transfer(address indexed from, address indexed to, uint256 value)
```

#### Parameters

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| from `indexed` | address | undefined   |
| to `indexed`   | address | undefined   |
| value          | uint256 | undefined   |

### VaultFeesCollectionEvent

Emitted when fees are transferred to fee recipient

```solidity title="Solidity"
event VaultFeesCollectionEvent(uint256 feeInRisky, uint256 feeInStable, uint16 round, address indexed feeRecipient)
```

#### Parameters

| Name                   | Type    | Description                      |
| ---------------------- | ------- | -------------------------------- |
| feeInRisky             | uint256 | Vault fee in risky asset         |
| feeInStable            | uint256 | Vault fee in stable asset        |
| round                  | uint16  | Current round                    |
| feeRecipient `indexed` | address | The address of the fee recipient |

### VaultManagerSetEvent

Emitted when owner sets new vault manager contract

```solidity title="Solidity"
event VaultManagerSetEvent(address indexed vaultManager)
```

#### Parameters

| Name                   | Type    | Description                                        |
| ---------------------- | ------- | -------------------------------------------------- |
| vaultManager `indexed` | address | Emitted when owner sets new vault manager contract |

### VolatilitySetEvent

Emitted when keeper manually sets next round&#39;s implied volatility

```solidity title="Solidity"
event VolatilitySetEvent(uint32 volatility, uint16 round)
```

#### Parameters

| Name       | Type   | Description                            |
| ---------- | ------ | -------------------------------------- |
| volatility | uint32 | Implied volatility in decimals of four |
| round      | uint16 | Current round                          |

### WithdrawCompleteEvent

Emitted when user&#39;s requested withdrawal is complete

```solidity title="Solidity"
event WithdrawCompleteEvent(address indexed account, uint256 shares, uint256 riskyAmount, uint256 stableAmount)
```

#### Parameters

| Name              | Type    | Description                                 |
| ----------------- | ------- | ------------------------------------------- |
| account `indexed` | address | Address of the `msg.sender`                 |
| shares            | uint256 | Number of shares to withdraw from vault     |
| riskyAmount       | uint256 | Amount of risky tokens to transfer to user  |
| stableAmount      | uint256 | Amount of stable tokens to transfer to user |

### WithdrawRequestEvent

Emitted when user requests a withdrawal

```solidity title="Solidity"
event WithdrawRequestEvent(address indexed account, uint256 shares, uint16 round)
```

#### Parameters

| Name              | Type    | Description                  |
| ----------------- | ------- | ---------------------------- |
| account `indexed` | address | Address of the `msg.sender`  |
| shares            | uint256 | Number of shares to withdraw |
| round             | uint16  | Current round                |
