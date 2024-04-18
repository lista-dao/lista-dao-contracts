const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')
// Global Variables
let ray = '000000000000000000000000000', // 27 Decimals
  rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()

  const {symbol, tokenAddress, ilk, gemJoin, clipper, oracle} = {
    "symbol": "BTCB200",
    "tokenAddress": "0x4Bb08858bc554043C157B7d7138F0cFf98Be66DC",
    "ilk": "0x4254434232303000000000000000000000000000000000000000000000000000",
    "gemJoin": "0xC515DF28De85F4472D32B3b702cefcE2726f9660",
    "gemJoinImplementation": "0xB64BDeBdC7572D48fb29fDB1352080abD9bc2fc8",
    "clipper": "0x9739bC66BCdbadbc0dcc55f1Ea22E1A571d692D6",
    "clipperImplementation": "0x21f8Ff25c0cE07521dF5c10c2E04f13F86325988",
    "oracle": "0xb27c1f72E0B9AA66d0f221AFfC24CBCbaFB4b18D",
    "oracleImplementation": "0x903DF343286A0C626337ef35cE106Db3fa7c821A",
    "priceFeed": "0x491fD333937522e69D1c3FB944fbC5e95eEF9f59"
  }

  // core parameters
  //const mat = '15' + ray // Liquidation Ratio
  const mat = '1333333333333333333333333333' // Liquidation Ratio
  const line = '50000000' + rad // Debt Ceiling
  //const dust = '100000000000000000' + ray // Debt Floor
  const dust = '1' + ray // Debt Floor
  const hole = '50000000' + rad // Liquidation
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

  await interaction.poke(tokenAddress)
  await interaction.drip(tokenAddress)

  console.log('Finished')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
