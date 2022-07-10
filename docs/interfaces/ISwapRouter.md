---
description: ISwapRouter
---

# ISwapRouter.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/interfaces/ISwapRouter.sol)

Interface for Uniswap Router to swap tokens

:::note Details
Taken from https://github.com/Uniswap/v3-periphery
:::

## Methods

### exactInputSingle

```solidity title="Solidity"
function exactInputSingle(ISwapRouter.ExactInputSingleParams params) external payable returns (uint256 amountOut)
```

#### Parameters

| Name   | Type                               | Description |
| ------ | ---------------------------------- | ----------- |
| params | ISwapRouter.ExactInputSingleParams | undefined   |

#### Returns

| Name      | Type    | Description |
| --------- | ------- | ----------- |
| amountOut | uint256 | undefined   |
