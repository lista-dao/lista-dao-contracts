const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')
const contractAddresses = require("./contract_address.json");
const {transferProxyAdminOwner} = require("../upgrades/utils/upgrade_utils");
const path = require("path");
const fs = require("fs");
const {addCollateral} = require('../utils/add_collateral')

// Global Variables
let rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

    const [deployer] = await ethers.getSigners()
    let NEW_OWNER = '0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37'
    let PROXY_ADMIN_OWNER = '0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253'
    let oracleName = 'mCAKEOracle';
    let oracleInitializeArgs = [];
    let oracleInitializer = 'initialize';

    const symbol = 'mCAKE'
    let tokenAddress = '0x581fa684d0ec11ccb46b1d92f1f24c8a3f95c0ca' // mCAKE token address on BSC Mainnet

    if (hre.network.name === 'bsc_testnet') {
        NEW_OWNER = process.env.OWNER || deployer.address
        PROXY_ADMIN_OWNER = process.env.PROXY_ADMIN_OWNER || deployer.address
        // testnet token address
        tokenAddress = '0x70ad940d73415CDDAc47861e9691795AA7a119e1'
    }

    // add collateral
    await addCollateral({
        symbol,
        tokenAddress,
        oracleName,
        oracleInitializeArgs,
        oracleInitializer,
        owner: NEW_OWNER,
        proxyAdminOwner: PROXY_ADMIN_OWNER,
        clipperBuf: '1100000000000000000000000000',
        clipperTail: '10800',
        clipperCusp: '600000000000000000000000000',
        clipperChip: '0',
        clipperTip: '5' + rad,
        clipperStopped: '0'
    })
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
