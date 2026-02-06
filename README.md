# Templar Finance protocol

![Stars](https://img.shields.io/github/stars/insecureMary/Templar-Finance)
![Contributors](https://img.shields.io/github/stars/insecureMary/Templar-Finance?color=brightgreen)
![Issues](https://img.shields.io/github/issues/insecureMary/Templar-Finance)
![License](https://img.shields.io/github/license/insecureMary/Templar-Finance)

## About Templar-Finance 
Templar finance is a decentralized liquidity protocol that enables users to supply or borrow assets in a trust-minimized environment. Liquidity providers (Investors) supply capital to the protocol and earn gains on the capital supplied, while borrowers can access this liquidity by depositing assets valued above the borrowed amount as collateral. Tradon is designed to function as a much more easier, accessible and decentralised version of a traditional banking system. 

## Resources

* [Documentation](https:/tradon.tech) - Read the Templar docs for a more indepth explanation.


## Overview
This repository holds the smart contract code for the pilot version of the Templar finance protocol. It contains the logic to:
1. Create and register new vault
2. Unregister an existing vault
3. Set and remove manager for all vaults
4. Deposit asset into the vault
5. Cancel pending deposits
6. Fufil pending deposits
7. Mint shares  
8. Redeem shares
9. Cancel redeeming of shares
10. Set and remove operators for vaults
11. Upgrade investment logic with upgradeability patters

## Dependencies

The smart contracts in this repository import code from:
1. [Forge-std](https://github.com/foundry-rs/forge-std)
2. [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
3. [OpenZeppelin Contracts Upgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable)

To check version of the dependencies, use `git submodule status`.

## Setup

#### Make sure to have foundry installed
``` javascript
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
```

#### Verify installation:
` forge --version`

#### Clone the Repository
```
    git clone https://github.com/insecureMary/Templar-Finance.git
    cd Templar-Finance
```

#### Install Dependencies
`forge install`

#### Build the contracts
`forge build`

#### Run all tests
`forge test`

#### Run a specific test
`forge test --mt <test_name>`

## Audit Report
Audits are currently in progress, will be updated soon.

