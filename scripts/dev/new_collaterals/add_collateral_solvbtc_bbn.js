const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')
// Global Variables
let ray = '000000000000000000000000000', // 27 Decimals
    rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

    [deployer] = await ethers.getSigners()
    const {symbol, tokenAddress, ilk, gemJoin, clipper, oracle} = {
        "symbol": "SolvBTC.BBN",
        "tokenAddress": "0x16D9A837e0D1AAC45937425caC26CcB729388C9A",
        "ilk": "0x536f6c764254432e42424e000000000000000000000000000000000000000000",
        "gemJoin": "0x5adABE1b1fDDFb76c3B7f3Eef9F5DDA7E4f5A347",
        "gemJoinImplementation": "0x2c124E030D956F3351A2D205e757941326e3604E",
        "clipper": "0xD6A5497e7dbc30a8e9f0b20686a0336B9F2fAc92",
        "clipperImplementation": "0x5BA7D1c3f967c00179CE43283C06bcb374838A1D",
        "oracle": "0x3e6c4Efe6D6A470439795756BEDE9f4cd6BdDd5d",
        "oracleImplementation": "0x5e39f70038Db1083756ED494cf3eADfA07E49ED4",
        "oracleInitializeArgs": [
            "0x79e9675cDe605Ef9965AbCE185C5FD08d0DE16B1"
        ],
        "owner": "0x05E3A7a66945ca9aF73f66660f22ffB36332FA54",
        "proxyAdminOwner": "0x05E3A7a66945ca9aF73f66660f22ffB36332FA54"
    }

    // core parameters
    const mat = '2000000000000000000000000000' // Liquidation Ratio
    const line = '500000' + rad // Debt Ceiling
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

    console.log('symbol:        ' + symbol)
    console.log('tokenAddress:  ' + tokenAddress)
    console.log('ilk:           ' + ilk)

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


    await interaction.setCollateralDuty(tokenAddress, '1000000002293273137447729405'); //apr 7.5%
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
