---
description: ParetoVault
---

# ParetoVault.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/vaults/ParetoVault.sol)

Based on RibbonVault.sol See https://docs.ribbon.finance/developers/ribbon-v2

## Methods

### MIN_LIQUIDITY

Always keep a few units of both assets, used to create pools The owner is responsible for providing this initial deposit In fee computation, guarantee at least this amount is left in vault

```solidity title="Solidity"
function MIN_LIQUIDITY() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### TOKEN_NAME

Name of the Pareto receipt token

```solidity title="Solidity"
function TOKEN_NAME() external view returns (string)
```

#### Returns

| Name | Type   | Description |
| ---- | ------ | ----------- |
| \_0  | string | undefined   |

### TOKEN_SYMBOL

Symbol of the Pareto receipt token

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

Completes a requested withdraw from past round.

```solidity title="Solidity"
function completeWithdraw() external nonpayable
```

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

Sets up the vault condition on the current vault

```solidity title="Solidity"
function deployVault() external nonpayable
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

### depositReceipts

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

### getAccountShares

Returns the number of shares (+unredeemed shares) for one account

```solidity title="Solidity"
function getAccountShares(address account) external view returns (uint256 shares)
```

#### Parameters

| Name    | Type    | Description                          |
| ------- | ------- | ------------------------------------ |
| account | address | is the address to lookup balance for |

#### Returns

| Name   | Type    | Description                          |
| ------ | ------- | ------------------------------------ |
| shares | uint256 | is the share balance for the account |

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

Save gas for writing values into the roundSharePriceIn(Risky/Stable) map

```solidity title="Solidity"
function initRounds(uint256 numRounds) external nonpayable
```

:::note Details
Writing 1 makes subsequent writes warm, reducing the gas from 20k to 5k
:::

#### Parameters

| Name      | Type    | Description                                      |
| --------- | ------- | ------------------------------------------------ |
| numRounds | uint256 | is the number of rounds to initialize in the map |

### keeper

Keeper who manually managers contract

```solidity title="Solidity"
function keeper() external view returns (address)
```

#### Returns

| Name | Type    | Description           |
| ---- | ------- | --------------------- |
| \_0  | address | Address of the keeper |

### managementFee

```solidity title="Solidity"
function managementFee() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### managerState

```solidity title="Solidity"
function managerState() external view returns (uint128 manualStrike, uint16 manualStrikeRound, uint32 manualVolatility, uint16 manualVolatilityRound, uint32 manualGamma, uint16 manualGammaRound)
```

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

```solidity title="Solidity"
function performanceFee() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### poolState

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

### rollover

Rolls the vault&#39;s funds into the next vault Performs rebalancing of vault asseets Deposits tokens into new Primitive pool Pending assets get counted into locked here

```solidity title="Solidity"
function rollover() external nonpayable
```

### roundSharePriceInRisky

```solidity title="Solidity"
function roundSharePriceInRisky(uint256) external view returns (uint256)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### roundSharePriceInStable

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

Seeds vault with minimum funding

```solidity title="Solidity"
function seedVault() external nonpayable
```

:::note Details
Requires approval by owner to contract of at least MIN_LIQUIDITY This is used to satisfy the minimum liquidity to start RMM-01 pools At least this liquidity will always remain in the vault regardless of withdrawals or fee transfers
:::

### setFeeRecipient

Sets the fee recipient

```solidity title="Solidity"
function setFeeRecipient(address newFeeRecipient) external nonpayable
```

#### Parameters

| Name            | Type    | Description                             |
| --------------- | ------- | --------------------------------------- |
| newFeeRecipient | address | is the address of the new fee recipient |

### setGamma

Optionality to manually set gamma

```solidity title="Solidity"
function setGamma(uint32 gamma) external nonpayable
```

#### Parameters

| Name  | Type   | Description                                         |
| ----- | ------ | --------------------------------------------------- |
| gamma | uint32 | is 1-fee of the new pool. Important for replication |

### setKeeper

Sets the keeper

```solidity title="Solidity"
function setKeeper(address newKeeper) external nonpayable
```

#### Parameters

| Name      | Type    | Description                      |
| --------- | ------- | -------------------------------- |
| newKeeper | address | is the address of the new keeper |

### setManagementFee

Sets the management fee for the vault

```solidity title="Solidity"
function setManagementFee(uint256 newManagementFee) external nonpayable
```

#### Parameters

| Name             | Type    | Description           |
| ---------------- | ------- | --------------------- |
| newManagementFee | uint256 | is the management fee |

### setPerformanceFee

Sets the performance fee for the vault

```solidity title="Solidity"
function setPerformanceFee(uint256 newPerformanceFee) external nonpayable
```

#### Parameters

| Name              | Type    | Description            |
| ----------------- | ------- | ---------------------- |
| newPerformanceFee | uint256 | is the performance fee |

### setStrikePrice

Optionality to manually set strike price

```solidity title="Solidity"
function setStrikePrice(uint128 strikePrice) external nonpayable
```

#### Parameters

| Name        | Type    | Description                         |
| ----------- | ------- | ----------------------------------- |
| strikePrice | uint128 | is the strike price of the new pool |

### setUniswapPoolFee

Sets the fee to search for when routing

```solidity title="Solidity"
function setUniswapPoolFee(uint24 newPoolFee) external nonpayable
```

#### Parameters

| Name       | Type   | Description         |
| ---------- | ------ | ------------------- |
| newPoolFee | uint24 | is the new pool fee |

### setVaultManager

Sets the new Vault Manager contract

```solidity title="Solidity"
function setVaultManager(address newVaultManager) external nonpayable
```

#### Parameters

| Name            | Type    | Description                                |
| --------------- | ------- | ------------------------------------------ |
| newVaultManager | address | is the address of the new manager contract |

### setVolatility

Optionality to manually set implied volatility

```solidity title="Solidity"
function setVolatility(uint32 volatility) external nonpayable
```

#### Parameters

| Name       | Type   | Description                  |
| ---------- | ------ | ---------------------------- |
| volatility | uint32 | is the sigma of the new pool |

### stable

Stable token of the risky / stable pair

```solidity title="Solidity"
function stable() external view returns (address)
```

#### Returns

| Name | Type    | Description                          |
| ---- | ------- | ------------------------------------ |
| \_0  | address | Address of the stable token contract |

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

Return vault&#39;s total balance of risky assets, including amounts locked into Primitive

```solidity title="Solidity"
function totalRisky() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

### totalStable

Return vault&#39;s total balance of stable assets, including amounts locked into Primitive

```solidity title="Solidity"
function totalStable() external view returns (uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | uint256 | undefined   |

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

```solidity title="Solidity"
function uniswapParams() external view returns (address router, uint24 poolFee)
```

#### Returns

| Name    | Type    | Description |
| ------- | ------- | ----------- |
| router  | address | undefined   |
| poolFee | uint24  | undefined   |

### vaultManager

ParetoManager contract used to specify options

```solidity title="Solidity"
function vaultManager() external view returns (address)
```

#### Returns

| Name | Type    | Description                           |
| ---- | ------- | ------------------------------------- |
| \_0  | address | Address of the ParetoManager contract |

### vaultState

```solidity title="Solidity"
function vaultState() external view returns (uint16 round, uint104 lockedRisky, uint104 lockedStable, uint104 lastLockedRisky, uint104 lastLockedStable, uint128 pendingRisky, uint256 lastQueuedWithdrawRisky, uint256 lastQueuedWithdrawStable, uint256 currQueuedWithdrawShares, uint256 totalQueuedWithdrawShares)
```

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

Emitted when keeper burns RMM-01 LP tokens for assets

```solidity title="Solidity"
event ClosePositionEvent(bytes32 poolId, uint256 burnLiquidity, uint256 riskyAmount, uint256 stableAmount, address indexed keeper)
```

#### Parameters

| Name             | Type    | Description |
| ---------------- | ------- | ----------- |
| poolId           | bytes32 | undefined   |
| burnLiquidity    | uint256 | undefined   |
| riskyAmount      | uint256 | undefined   |
| stableAmount     | uint256 | undefined   |
| keeper `indexed` | address | undefined   |

### DeployVaultEvent

Emitted when keeper creates a new RMM-01 pool

```solidity title="Solidity"
event DeployVaultEvent(bytes32 poolId, uint128 strikePrice, uint32 volatility, uint32 gamma, address indexed keeper)
```

#### Parameters

| Name             | Type    | Description |
| ---------------- | ------- | ----------- |
| poolId           | bytes32 | undefined   |
| strikePrice      | uint128 | undefined   |
| volatility       | uint32  | undefined   |
| gamma            | uint32  | undefined   |
| keeper `indexed` | address | undefined   |

### DepositEvent

Emitted when user deposits risky asset into vault

```solidity title="Solidity"
event DepositEvent(address indexed account, uint256 riskyAmount, uint16 round)
```

#### Parameters

| Name              | Type    | Description |
| ----------------- | ------- | ----------- |
| account `indexed` | address | undefined   |
| riskyAmount       | uint256 | undefined   |
| round             | uint16  | undefined   |

### FeeRecipientSetEvent

Emitted when owner sets new recipient address for fees

```solidity title="Solidity"
event FeeRecipientSetEvent(address indexed keeper)
```

#### Parameters

| Name             | Type    | Description |
| ---------------- | ------- | ----------- |
| keeper `indexed` | address | undefined   |

### GammaSetEvent

Emitted when keeper manually sets next round&#39;s trading fee

```solidity title="Solidity"
event GammaSetEvent(uint32 gamma, uint16 round)
```

#### Parameters

| Name  | Type   | Description |
| ----- | ------ | ----------- |
| gamma | uint32 | undefined   |
| round | uint16 | undefined   |

### KeeperSetEvent

Emitted when owner sets new keeper address

```solidity title="Solidity"
event KeeperSetEvent(address indexed keeper)
```

#### Parameters

| Name             | Type    | Description |
| ---------------- | ------- | ----------- |
| keeper `indexed` | address | undefined   |

### ManagementFeeSetEvent

Emitted when owner sets new management fee

```solidity title="Solidity"
event ManagementFeeSetEvent(uint256 managementFee, uint256 newManagementFee)
```

#### Parameters

| Name             | Type    | Description |
| ---------------- | ------- | ----------- |
| managementFee    | uint256 | undefined   |
| newManagementFee | uint256 | undefined   |

### OpenPositionEvent

Emitted when keeper deposits vault assets into RMM-01 pool

```solidity title="Solidity"
event OpenPositionEvent(bytes32 poolId, uint256 riskyAmount, uint256 stableAmount, uint256 returnLiquidity, address indexed keeper)
```

#### Parameters

| Name             | Type    | Description |
| ---------------- | ------- | ----------- |
| poolId           | bytes32 | undefined   |
| riskyAmount      | uint256 | undefined   |
| stableAmount     | uint256 | undefined   |
| returnLiquidity  | uint256 | undefined   |
| keeper `indexed` | address | undefined   |

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

Emitted when owner sets new performance fee

```solidity title="Solidity"
event PerformanceFeeSetEvent(uint256 performanceFee, uint256 newPerformanceFee)
```

#### Parameters

| Name              | Type    | Description |
| ----------------- | ------- | ----------- |
| performanceFee    | uint256 | undefined   |
| newPerformanceFee | uint256 | undefined   |

### RebalanceVaultEvent

Emitted as an internal step in rollover

```solidity title="Solidity"
event RebalanceVaultEvent(uint256 initialRisky, uint256 initialStable, uint256 optimalRisky, uint256 optimalStable, address indexed keeper)
```

#### Parameters

| Name             | Type    | Description                                            |
| ---------------- | ------- | ------------------------------------------------------ |
| initialRisky     | uint256 | /Stable are the amounts of each token pre-rebalancing  |
| initialStable    | uint256 | undefined                                              |
| optimalRisky     | uint256 | /Stable are the amounts of each token post-rebalancing |
| optimalStable    | uint256 | undefined                                              |
| keeper `indexed` | address | undefined                                              |

### StrikePriceSetEvent

Emitted when keeper manually sets next round&#39;s strike price

```solidity title="Solidity"
event StrikePriceSetEvent(uint128 strikePrice, uint16 round)
```

#### Parameters

| Name        | Type    | Description |
| ----------- | ------- | ----------- |
| strikePrice | uint128 | undefined   |
| round       | uint16  | undefined   |

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

Emitted when fees are transfered to feeRecipient

```solidity title="Solidity"
event VaultFeesCollectionEvent(uint256 feeInRisky, uint256 feeInStable, uint16 round, address indexed feeRecipient)
```

#### Parameters

| Name                   | Type    | Description |
| ---------------------- | ------- | ----------- |
| feeInRisky             | uint256 | undefined   |
| feeInStable            | uint256 | undefined   |
| round                  | uint16  | undefined   |
| feeRecipient `indexed` | address | undefined   |

### VaultManagerSetEvent

Emitted when owner sets new vault manager contract

```solidity title="Solidity"
event VaultManagerSetEvent(address indexed vaultManager)
```

#### Parameters

| Name                   | Type    | Description |
| ---------------------- | ------- | ----------- |
| vaultManager `indexed` | address | undefined   |

### VolatilitySetEvent

Emitted when keeper manually sets next round&#39;s implied volality

```solidity title="Solidity"
event VolatilitySetEvent(uint32 volatility, uint16 round)
```

#### Parameters

| Name       | Type   | Description |
| ---------- | ------ | ----------- |
| volatility | uint32 | undefined   |
| round      | uint16 | undefined   |

### WithdrawCompleteEvent

Emitted when user&#39;s queued withdrawal is complete

```solidity title="Solidity"
event WithdrawCompleteEvent(address indexed account, uint256 shares, uint256 riskyAmount, uint256 stableAmount)
```

#### Parameters

| Name              | Type    | Description |
| ----------------- | ------- | ----------- |
| account `indexed` | address | undefined   |
| shares            | uint256 | undefined   |
| riskyAmount       | uint256 | undefined   |
| stableAmount      | uint256 | undefined   |

### WithdrawRequestEvent

Emitted when user requests a withdrawal

```solidity title="Solidity"
event WithdrawRequestEvent(address indexed account, uint256 shares, uint16 round)
```

#### Parameters

| Name              | Type    | Description |
| ----------------- | ------- | ----------- |
| account `indexed` | address | undefined   |
| shares            | uint256 | undefined   |
| round             | uint16  | undefined   |
