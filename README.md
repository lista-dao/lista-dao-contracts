# HELIO

`cp .env.example .env`
edit .env with your variables 

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