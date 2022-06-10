# Pareto Theta Vault v1

Pareto Theta Vault v1 is the first version of Pareto's Theta Vault built on top of Primitive's RMM-01 pools.

## Citations

This code is heavily based on Ribbon v2's [implementation](https://github.com/ribbon-finance/ribbon-v2). Additionally, we incorporate feedback from Ante Finance's [review](https://mirror.xyz/antefinance.eth/B7tmf4E20rzoy4ZIMd4n4Xls3vTOwjx0O4ZpYewO6l4). 

## TODO

- Allow anytime withdraw from the vault
- Don't assume risky and stable are balanced
- Create `ParetoThetaVault` class to inherit from `ParetoVault` and a upgradeable storage class, much like Ribbon
- Prevent cold writes by initializing round prices
- Support redeeming shares? 
- Lending unused risky/stable to Compound
- Implement `createPosition` and `settlePosition` in `VaultLifecycle.sol` using Primitive manager functions
- Separate storage to be upgradeable from `ParetoVault.sol`
- Fix stack limit bug on compilation