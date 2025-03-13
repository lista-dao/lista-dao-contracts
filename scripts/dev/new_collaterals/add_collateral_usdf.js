const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')
// Global Variables
let ray = '000000000000000000000000000', // 27 Decimals
  rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()

  const {symbol, tokenAddress, ilk, gemJoin, clipper, oracle} = {
    "symbol":"USDF",
    "tokenAddress":"0x40326b7d4B52B750E98456388a24603E977eC56B",
    "ilk":"0x5553444600000000000000000000000000000000000000000000000000000000",
    "gemJoin":"0x13d9d39833CDFcDB76161BA40ddfa927dEbeb168",
    "gemJoinImplementation":"0x24418D2BEB9d322dDAe728C45297f5cb82238b2d",
    "clipper":"0x502932f061eA3a179F3B69132f870B7EC566970A",
    "clipperImplementation":"0x98f2Fae3057d81Fc6b35bc8FaeA209c585f87f9E",
    "oracle":"0xE4B29F6f973D7391277929aFB0fE4CDBD0147f68",
    "oracleImplementation":"0x820739E7719C35A1d405ccd4bd227519B9d85e65",
    "oracleInitializeArgs":[
      "0x79e9675cDe605Ef9965AbCE185C5FD08d0DE16B1"
    ],
    "owner":"0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06",
    "proxyAdminOwner":"0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06"
  }

  // core parameters
  const mat = '1200000000000000000000000000' // Liquidation Ratio 120%
  const line = '1000000000000000000000000000000000000000000000000000' // Debt Ceiling 1M
  const dust = '15' + rad // Debt Floor
  const hole = '5000000' + rad // Liquidation
  const chop = '1100000000000000000' // Liquidation


  let VAT = '0x33A34eAB3ee892D40420507B820347b1cA2201c4'
  let DOG = '0xd57E7b53a1572d27A04d9c1De2c4D423f1926d0B'
  let SPOT = '0x49bc2c4E5B035341b7d92Da4e6B267F7426F3038'
  let INTERACTION = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
  let AUCTION_PROXY

  if (hre.network.name === 'bsc_testnet') {
    VAT = '0x382589e4dE7A061fcb9716c203983d8FE847AE0b'
    DOG = '0x3d2165EDf3Cc07992f54d9310FB800C81BC641F7'
    SPOT = '0xa2882B6AC7cBA1b8784BF5D72F38CF0E6416263e'
    INTERACTION = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
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


  await interaction.setCollateralDuty(tokenAddress, '1000000003734875566854894262'); //apr 12.5%
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
