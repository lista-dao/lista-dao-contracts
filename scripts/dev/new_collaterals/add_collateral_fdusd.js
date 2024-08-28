const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')
// Global Variables
let ray = '000000000000000000000000000', // 27 Decimals
  rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()

  const {symbol, tokenAddress, ilk, gemJoin, clipper, oracle} = {
    "symbol":"FDUSD",
    "tokenAddress":"0xadbccCa89eC498F8B9B7F6A4B05206b113676861",
    "ilk":"0x4644555344000000000000000000000000000000000000000000000000000000",
    "gemJoin":"0xe345Ec2024AFFE36deb7a3f2C570BDAD05db55DD",
    "gemJoinImplementation":"0x90f843817c4643Be07C319037aB34f2db2BAe6f4",
    "clipper":"0xE6CFcAC82da8b0E3e3D3511894986d8e86A99101",
    "clipperImplementation":"0x704C8d42Eb0a837E6AeCB970FE353d38F36fC0d7",
    "oracle":"0xbB1Cd910924CE7D3d540B36EbE09FD5588e06926",
    "oracleImplementation":"0x5993D217010a0993944a2984C7BE942dB0D3d195",
    "oracleInitializeArgs":[
      "0x79e9675cDe605Ef9965AbCE185C5FD08d0DE16B1"
    ],
    "owner":"0xF45FB2567C2E081a2C866bba10d3dc543AFa2920",
    "proxyAdminOwner":"0xF45FB2567C2E081a2C866bba10d3dc543AFa2920"
  }

  // core parameters
  const mat = '2000000000000000000000000000' // Liquidation Ratio
  const line = '5000000' + rad // Debt Ceiling
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
