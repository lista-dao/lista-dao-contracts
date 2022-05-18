# Interaction example

### Deposit

Assume user has some aBNBc tokens.

aBNBc is ERC20 complaint contract. 

1. Approve aBNBc(token) with deposit amount against interaction contract
2. Call `interaction.deposit(<token>, <amount>)`

### Borrow

1. Call `interaction.borrow(<token>, <amount_to_borrow>)`
`Token` is the collateral token that you want to use
Check that you have USB present in the wallet

### Auction

* `getTotalAuctionsCountForToken(<token>)` - gets total amount of auctions for collateral
* `getAllActiveAuctionsForToken(<token>)` - gets all active auctions for collateral
* `startAuction(<token>, <user_address>, <keeper_address>)` - starts an auction for a collateral, liquidates user and transfers incentives to keeper address
* `buyFromAuction(<token>, <auctionId>, <collateral_amount>, <max_price>, <receiver_address>)` - buys collateral in auction(before this call user should approve `collateral_mount * max_price / ray` amount of USB to DAOInteraction contract)
  1. `token` - address of collateral token
  2. `auctionId` - Id of auction
  3. `collateral_amount` - the maximum amount of collateral user wants to buy [wad]
  4. `max_price` - the maximum acceptable price in USB per unit collateral [ray]
  5. `receiver_address` - address that will receive the collateral


### Repay

1. Approve USB (it is also ERC20 complaint contract) against interaction
2. Call `interaction.payback(<token>, <amount_of_usb>)`

Note: aBNBc will stay collaterized(locked) in the vault.

### Withdraw

Unlock and transfer funds to the user

1. Call `interaction.withdraw(<token>, <abnbc_amount_to_withdraw>)`

## View functions

* `locked(<token>, <user_address>)` - Amount of aBNBc in collateral for a user
* `borrowed(<token>, <user_address>)` - Amount of USB borrowed by user
* `collateralPrice(<token>)` - price of the collateral asset(aBNBc) from Oracle
* `usbPrice(<token>)` - USB price
* `collateralRate(<token>)` - how much USB user can borrow for one token of collateral<br> 
                     i.e. 1 aBNBc worth `collateralRate` USB
* `depositTVL(<token>)` - Total aBNBc deposited nominated in $
* `collateralTVL(<token>)` - Total USB borrowed by all users
* `availableToBorrow(<token>, <user_address>)` - Collateral minus borrowed. In other words: free collateral (nominated in USB)
* `willBorrow(<token>, <user_address>, <amount>)` - Collateral minus borrowed with additional amount of aBNBc (`amount` can be negative).
* `currentLiquidationPrice(<token>, <user_address>)` - Price of aBNBc when user will be liquidated
* `estimatedLiquidationPrice(<token>, <user_address>, <amount>)` - Price of aBNBc when user will be liquidated with additional amount of aBNBc deposited/withdraw
* `borrowApr(<token>)` - Percent value, yearly APY with 6 decimals

## ABIs
[INTERACTION ABI](interfaces/DAOInteraction.json)

[IERC20 ABI](interfaces/IERC20.json)

## Addresses

* "INTERACTION": [0xE8A954826660a78FFf62652FeD243E3fef262014](https://testnet.bscscan.com/address/0xE8A954826660a78FFf62652FeD243E3fef262014),
* "mock aBNBc": [0x33284aFc0791F18011B86C2469A7625066345373](https://testnet.bscscan.com/address/0x33284aFc0791F18011B86C2469A7625066345373),
* "REAL aBNBc": [0x46dE2FBAf41499f298457cD2d9288df4Eb1452Ab](https://testnet.bscscan.com/address/0x46dE2FBAf41499f298457cD2d9288df4Eb1452Ab),
* "USB": [0x86A6bdb0101051a0F5FeeD0941055Bca74F21D6C](https://testnet.bscscan.com/address/0x86A6bdb0101051a0F5FeeD0941055Bca74F21D6C),

## String to bytes32

https://ethereum.stackexchange.com/a/23110

`web3.utils.hexToAscii(val)`

## REWARDS

### View Reward balance
`pendingRewards(<user_address>)` - Maximum amount of tokens that can be claimed by user.

### Claim
`claim(<user_address>, <amount>)` - Claim `amount` of user tokens and transfer them to the `user` wallet

### View distribution APY
`distributionApy()` - rate in percent (like borrowApr)

### ABI
[HelioRewards ABI](interfaces/HelioRewards.json)

## Addresses
* "HelioToken": [0x97BBBc81eBF1F130315b717b165Ebc9193a046Cd](https://testnet.bscscan.com/address/0x97BBBc81eBF1F130315b717b165Ebc9193a046Cd),
* "HelioRewards": [0x7ad1585f12742D21BBDD0e3Ed8DdE279B55565e3](https://testnet.bscscan.com/address/0x7ad1585f12742D21BBDD0e3Ed8DdE279B55565e3),