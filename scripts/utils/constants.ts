/**
 * Vault constants
 */

export enum CHAIN_ID {
  ETH_MAINNET = 1,
  ETH_RINKEBY = 4,
  ETH_GANACHE = 5777
};

/**************************
 * Primitive contracts
 **************************/

export const PRIMITIVE_MANAGER = {
  [CHAIN_ID.ETH_MAINNET]: "TODO",
  [CHAIN_ID.ETH_GANACHE]: "TODO",
}

/**************************
 * Token contracts
 **************************/

export const WETH_CONTRACT = {
  [CHAIN_ID.ETH_MAINNET]: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  [CHAIN_ID.ETH_RINKEBY]: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
};

export const USDC_CONTRACT = {
  [CHAIN_ID.ETH_MAINNET]: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  [CHAIN_ID.ETH_RINKEBY]: "0x522064c1EafFEd8617BE64137f66A71D6C5c9aA3",
};

/**************************
 * Chainlink oracles
 **************************/

export const ETH_PRICE_ORACLE = {
  [CHAIN_ID.ETH_MAINNET]: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
};

export const USDC_PRICE_ORACLE = {
  [CHAIN_ID.ETH_MAINNET]: "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6",
};

// From `Crypto Volatility Index`
export const IV_ORACLE = {
  [CHAIN_ID.ETH_MAINNET]: "0x1B58B67B2b2Df71b4b0fb6691271E83A0fa36aC5"
};


/**************************
 * Uniswap pools
 **************************/

 export const ETH_USDC_POOL = {
  // NOTE: Uniswap v3 - USDC / ETH 0.3%
  [CHAIN_ID.ETH_MAINNET]: "0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8",
};