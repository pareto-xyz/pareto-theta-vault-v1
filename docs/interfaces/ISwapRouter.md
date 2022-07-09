---
description: Router token swapping functionality
---

# ISwapRouter.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contracts/interfaces/ISwapRouter.sol)

Source: https://github.com/Uniswap/v3-peripheryFunctions for swapping tokens via Uniswap V3

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
