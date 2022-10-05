# Pareto Theta Vault v1

[![](https://img.shields.io/github/stars/pareto-xyz/pareto-theta-vault-v1?style=social)](https://img.shields.io/github/stars/pareto-xyz/pareto-theta-vault-v1?style=social)
![Twitter Follow](https://img.shields.io/twitter/follow/Paretoxyz?style=social)
[![Tests](https://github.com/pareto-xyz/pareto-theta-vault-v1/actions/workflows/ci.yaml/badge.svg)](https://github.com/pareto-xyz/pareto-theta-vault-v1/actions/workflows/ci.yaml)

**Disclaimer: This repository is no longer being actively maintained and has not been audited. Proceed as your own risk.**

Pareto's Theta Vault v1 is a Replicating Theta Vault built on top of Primitive's RMM-01 pools. Pareto's vault generates yield for depositors by operating an automated weekly covered call selling strategy. This involves selling upside token volatility in return for a premium.
 
The vault replicates the payoff of selling out-the-money Black-Scholes covered call options, which expire each Friday. It reinvest assets each week until users withdraw. It generates premiums by depositing in a replicating market maker (RMM), a type of automated market maker (AMM), rather than selling options via auctions. Please refer to this [paper](https://primitive.xyz/whitepaper-rmm-01.pdf) for more technical details.

## Documentation

A whitepaper for Pareto's Theta Vaults can be found [here](https://github.com/pareto-xyz/pareto-theta-vault-whitepaper). Additionally, helpful background and discussion can be found in this [paper](https://arxiv.org/abs/2205.09890) from the Primitive team. 

## Testing

Compile contracts with `yarn compile`. Run Tests with `yarn test`. To measure coverage, run `yarn coverage`.

There is 100% test coverage, that is, all external and internal functions within Pareto have at least 1 test. However, we are sure our tests could be improved. If you have suggestions, please reach out to us via email (team@paretolabs.xyz), Twitter (@paretoxyz) or Discord.

## Citations

This code is heavily based on Ribbon v2's [implementation](https://github.com/ribbon-finance/ribbon-v2). Additionally, we incorporate feedback from Ante Finance's [review](https://mirror.xyz/antefinance.eth/B7tmf4E20rzoy4ZIMd4n4Xls3vTOwjx0O4ZpYewO6l4).
