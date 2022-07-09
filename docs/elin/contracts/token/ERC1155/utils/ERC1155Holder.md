---
description: ERC1155Holder
---

# ERC1155Holder.sol

> [Read code on GitHub](https://github.com/pareto-xyz/pareto-theta-vault-v1/blob/main/contractselin/contracts/token/ERC1155/utils/ERC1155Holder.sol)

Simple implementation of `ERC1155Receiver` that will allow a contract to hold ERC1155 tokens. IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be stuck.

:::note Details
_Available since v3.1._
:::

## Methods

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
