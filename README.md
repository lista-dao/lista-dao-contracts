# HELIO

Helio is a set of smart contracts that enables users to earn rewards for providing liquidity to the MakerDAO protocol. Helio is designed to be a decentralized, trustless, and permissionless protocol.

## Usage
To use Helio, you will need to create a MakerDAO vault and deposit collateral into it. You can then use Helio to borrow DAI against your collateral. Helio will automatically start earning rewards for you.

To learn more about how to use Helio, please see the Helio documentation.



## Contracts

### MakerDAO contracts
* **abaci** — price decrease function for auctions
* **clip** — liquidation 2.0 mechanics
* **dog** — starts auctions
* **join** — ERC20 token adapters
* **jug** — stability fee collector
* **spot** — oracle price fetch
* **hay** — stable coin
* **vat** — core cdp vault
* **vow** — vault balance sheet. Keeps track of surplus&debt

### Rewards contracts
* **HelioRewards** — rewards distribution module
* **HelioToken** — rewards token
* **HelioOracle** - rewards token oracle

### Ceros contracts
* **CerosRouter** — finds the best way to obtain aBNBc.
* **CeToken** — underlying collateral token inside makerDao
* **CeVault** — stores obtained aBNBc
* **HelioProvider** — wraps BNB into ceABNBc via _CerosRouter_

### Interaction contract
* **Interaction** — proxy for makerDao contracts. 
Provide deposit&withdraw and borrow&payback functions for end users
* **AuctionProxy** — entrypoint for auction methods.
End users can start auctions and participate in it via this contract

### Unit Testing
The core MakerDAO contracts are already battletested and the mock folders are excluded from tests.

## Installation
To install Helio, clone the Helio repository and run the following commands:
```
git clone https://github.com/helio-money/helio-smart-contracts.git

cd helio-smart-contracts  

npm install
```
Install Hardhat :
```
npm install --save-dev hardhat
```

Install Yarn:
```
npm install --global yarn
```

Install dotenv:
```
npm install dotenv --save
```

`cp .env.example .env`
edit .env with your variables 

## Contributing
Helio is an open source project, and we welcome contributions from the community. If you would like to contribute to Helio, please see the Helio contribution guidelines.

## License
Helio is licensed under the ISC license.

