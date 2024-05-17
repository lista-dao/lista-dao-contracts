const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')
// Global Variables
let ray = '000000000000000000000000000', // 27 Decimals
  rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()

  const {symbol, tokenAddress, ilk, gemJoin, clipper, oracle} = {
    "symbol": "ezETH_1",
    "tokenAddress": "0xF88257D7674F3Bb7Aa1b946cd499233f4093695a",
    "ilk": "0x657a4554485f3100000000000000000000000000000000000000000000000000",
    "gemJoin": "0x0D2944d3e9E38b19b34d62716c2751f0684A2665",
    "gemJoinImplementation": "0xB64BDeBdC7572D48fb29fDB1352080abD9bc2fc8",
    "clipper": "0x58FEc3718470dD15b1CE6A773525629434A7C9c8",
    "clipperImplementation": "0x21f8Ff25c0cE07521dF5c10c2E04f13F86325988",
    "oracle": "0xeCf92977F937eAECf9F2124c4E3361d248A2988C",
    "oracleImplementation": "0xe9FD3c9B357be56C35ca51cDeA6165Ce17e982cF",
    "priceFeed": "0xc0e60De0CB09a432104C823D3150dDEEA90E8f7d"
  }

  // core parameters
  const mat = '2000000000000000000000000000' // Liquidation Ratio
  const line = '1000000' + rad // Debt Ceiling
  const dust = '15' + rad // Debt Floor
  const hole = '5000000' + rad // Liquidation
  const chop = '1100000000000000000' // Liquidation


  let VAT = '0x33A34eAB3ee892D40420507B820347b1cA2201c4'
  let DOG = '0xd57E7b53a1572d27A04d9c1De2c4D423f1926d0B'
  let SPOT = '0x49bc2c4E5B035341b7d92Da4e6B267F7426F3038'
  let INTERACTION = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
  let AUCTION_PROXY

  if (hre.network.name === 'bsc_testnet') {
    VAT = '0xC9eeBDB18bD05dCF981F340b838E8CdD946D60ad'
    DOG = '0x77e4FcEbCDd30447f6e2E486B00a552A6493da0F'
    SPOT = '0x15493D9141481505f7CA3e591Cea2cBB03637B1d'
    INTERACTION = '0xb7A5999AEaE17C37d07ac4b34e56757c96387c84'
    if (!AUCTION_PROXY) {
      // deploy AuctionProxy
      const AuctionProxy = await hre.ethers.getContractFactory('AuctionProxy')
      const auctionProxy = await AuctionProxy.deploy()
      await auctionProxy.waitForDeployment()
      AUCTION_PROXY = await auctionProxy.getAddress()
      console.log('AuctionProxy deployed to:', AUCTION_PROXY)
    }
  }


  console.log('symbol: ' + symbol)
  console.log('tokenAddress: ' + tokenAddress)
  console.log('ilk: ' + ilk)

  // configure the collateral
  console.log('interaction...')
  this.Interaction = await hre.ethers.getContractFactory('Interaction', {
    unsafeAllow: ['external-library-linking'],
    libraries: {
      AuctionProxy: AUCTION_PROXY
    },
  })
  const interaction = this.Interaction.attach(INTERACTION)
  await interaction.setCollateralType(tokenAddress, gemJoin, ilk, clipper, mat)

  console.log('vat...')
  this.Vat = await hre.ethers.getContractFactory('Vat')
  const vat = this.Vat.attach(VAT)
  await vat.rely(gemJoin)
  await vat.rely(clipper)
  await vat['file(bytes32,bytes32,uint256)'](ilk, ethers.encodeBytes32String('dust'), dust)
  await vat['file(bytes32,bytes32,uint256)'](ilk, ethers.encodeBytes32String('line'), line)

  console.log('spot...')
  this.Spot = await hre.ethers.getContractFactory('Spotter')
  const spot = this.Spot.attach(SPOT)
  await spot['file(bytes32,bytes32,address)'](ilk, ethers.encodeBytes32String('pip'), oracle)

  console.log('Dog...')
  this.Dog = await hre.ethers.getContractFactory('Dog')
  const dog = this.Dog.attach(DOG)
  await dog.rely(clipper)
  await dog['file(bytes32,bytes32,uint256)'](ilk, ethers.encodeBytes32String('hole'), hole)
  await dog['file(bytes32,bytes32,uint256)'](ilk, ethers.encodeBytes32String('chop'), chop) // 10%
  await dog['file(bytes32,bytes32,address)'](ilk, ethers.encodeBytes32String('clip'), clipper)


  await interaction.setCollateralDuty(tokenAddress, '1000000004431822000000000000'); //apr 15%
  console.log("set duty...");

  await interaction.poke(tokenAddress, { gasLimit: 1000000 })
  await interaction.drip(tokenAddress, { gasLimit: 1000000 })

  console.log('Finished')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
