# Interaction example

### Deposit

Assume user has some aBNBc tokens.

aBNBc is ERC20 complaint contract.

1. Approve aBNBc(token) with deposit amount against interaction contract
2. Call `interaction.deposit(<participant>, <token>, <amount>)`

### Borrow

1. Call `interaction.borrow(<token>, <amount_to_borrow>)`
`Token` is the collateral token that you want to use
Check that you have HAY present in the wallet

### Auction

* `getTotalAuctionsCountForToken(<token>)` - gets total amount of auctions for collateral
* `getAllActiveAuctionsForToken(<token>)` - gets all active auctions for collateral
* `startAuction(<token>, <user_address>, <keeper_address>)` - starts an auction for a collateral, liquidates user and transfers incentives to keeper address
* `buyFromAuction(<token>, <auctionId>, <collateral_amount>, <max_price>, <receiver_address>)` - buys collateral in auction(before this call user should approve `collateral_mount * max_price / ray` amount of HAY to DAOInteraction contract)
  1. `token` - address of collateral token
  2. `auctionId` - Id of auction
  3. `collateral_amount` - the maximum amount of collateral user wants to buy [wad]
  4. `max_price` - the maximum acceptable price in HAY per unit collateral [ray]
  5. `receiver_address` - address that will receive the collateral


### Repay

1. Approve HAY (it is also ERC20 complaint contract) against interaction
2. Call `interaction.payback(<token>, <amount_of_hay>)`

Note: aBNBc will stay collaterized(locked) in the vault.

### Withdraw

Unlock and transfer funds to the user

1. Call `interaction.withdraw(<token>, <abnbc_amount_to_withdraw>)`

## View functions

* `locked(<token>, <user_address>)` - Amount of aBNBc in collateral for a user
* `borrowed(<token>, <user_address>)` - Amount of HAY borrowed by user
* `collateralPrice(<token>)` - price of the collateral asset(aBNBc) from Oracle
* `hayPrice(<token>)` - HAY price
* `collateralRate(<token>)` - how much HAY user can borrow for one token of collateral<br>
                     i.e. 1 aBNBc worth `collateralRate` HAY
* `depositTVL(<token>)` - Total aBNBc deposited nominated in $
* `collateralTVL(<token>)` - Total HAY borrowed by all users
* `availableToBorrow(<token>, <user_address>)` - Collateral minus borrowed. In other words: free collateral (nominated in HAY)
* `willBorrow(<token>, <user_address>, <amount>)` - Collateral minus borrowed with additional amount of aBNBc (`amount` can be negative).
* `currentLiquidationPrice(<token>, <user_address>)` - Price of aBNBc when user will be liquidated
* `estimatedLiquidationPrice(<token>, <user_address>, <amount>)` - Price of aBNBc when user will be liquidated with additional amount of aBNBc deposited/withdraw
* `borrowApr(<token>)` - Percent value, yearly APY with 6 decimals

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

## Liquidation (DEV env)

1. Provide collateral
2. Borrow some hay, note the estimated liquidation price
3. Set oracle price below your liquidation price
4. Visit liquidation page on the frontend
5. Note your address in the list and press `liquidate` button
6. Your hBNB will be burned and you will receive any leftover in hay after liquidation happened

# Deployment
## Local deploy
```shell
npx hardhat run scripts/deploy/1_deploy_all.js --network hardhat
```