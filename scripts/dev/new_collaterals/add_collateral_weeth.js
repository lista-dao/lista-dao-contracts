const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')
// Global Variables
let ray = '000000000000000000000000000', // 27 Decimals
  rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()

  const {symbol, tokenAddress, ilk, gemJoin, clipper, oracle} = {
    "symbol": "weETH",
    "tokenAddress": "0x6101D440EbF918F44706197a1acB884d621CA1F7",
    "ilk": "0x7765455448000000000000000000000000000000000000000000000000000000",
    "gemJoin": "0x713715fdcE98AE4968f2fb698a45a1Ef4Ebe9007",
    "gemJoinImplementation": "0xB64BDeBdC7572D48fb29fDB1352080abD9bc2fc8",
    "clipper": "0x070b49ddfB54367Ba80AbC5bdaAE264cC1Fc3c71",
    "clipperImplementation": "0x21f8Ff25c0cE07521dF5c10c2E04f13F86325988",
    "oracle": "0xA3C34E9bF4b0aFA9FAC5eFc2Fd7A3DAFFAa1089b",
    "oracleImplementation": "0xb926D390f5a9b9920c157248FD74B47AaC1062Cd",
    "oracleInitializeArgs": [
      "0x77D231e51614C84e15CCC38E2a52BFab49D6853C",
      "0x635780E5D02Ab29d7aE14d266936A38d3D5B0CC5"
    ],
    "owner": "0x0C6f6b0C6f78950445133FADe7DECD64c0bDd093",
    "proxyAdminOwner": "0x0C6f6b0C6f78950445133FADe7DECD64c0bDd093"
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
  //await interaction.removeCollateralType(tokenAddress)

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
