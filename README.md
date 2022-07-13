# Pareto Theta Vault v1

[![](https://img.shields.io/github/stars/pareto-xyz/pareto-theta-vault-v1?style=social)](https://img.shields.io/github/stars/pareto-xyz/pareto-theta-vault-v1?style=social)
![Twitter Follow](https://img.shields.io/twitter/follow/Paretoxyz?style=social)
[![Tests](https://github.com/pareto-xyz/pareto-theta-vault-v1/actions/workflows/ci.yaml/badge.svg)](https://github.com/pareto-xyz/pareto-theta-vault-v1/actions/workflows/ci.yaml)

Pareto's Theta Vault v1 is a Replicating Theta Vault built on top of Primitive's RMM-01 pools. Pareto's vault generates yield for depositors by operating an automated weekly covered call selling strategy. This involves selling upside token volatility in return for a premium.

The vault replicates the payoff of selling out-the-money Black-Scholes covered call options, which expire each Friday. It reinvest assets each week until users withdraw. 

It generates premiums by depositing in a replicating market maker (RMM), a type of automated market maker (AMM), rather than selling options via auctions.

## Documentation

The contract documentation is hosted here: [Pareto Docs](https://pareto-labs.gitbook.io/technical/GNswlmo7LarKUIJ2E8ja).

## Testing

Compile contracts with `yarn compile`. Run Tests with `yarn test`.

## Citations

This code is heavily based on Ribbon v2's [implementation](https://github.com/ribbon-finance/ribbon-v2). Additionally, we incorporate feedback from Ante Finance's [review](https://mirror.xyz/antefinance.eth/B7tmf4E20rzoy4ZIMd4n4Xls3vTOwjx0O4ZpYewO6l4).
