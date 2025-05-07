const fs = require('fs')
const path = require('path')
const {ethers, upgrades} = require('hardhat')
const {addCollateral_Origin} = require('../utils/add_collateral')

// Global Variables
let rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()
  let NEW_OWNER = '0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37'
  let PROXY_ADMIN_OWNER = '0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253'

  const symbol = 'asUSDF'
  let tokenAddress = '0x917AF46B3C3c6e1Bb7286B9F59637Fb7C65851Fb' // asUSDF token address on BSC Mainnet
  let oracleName = 'AsUsdfOracle';
  let oracleInitializeArgs = ['0xf3afD82A4071f272F403dC176916141f44E6c750'];
  let oracleInitializer = 'initialize';

  if (hre.network.name === 'bsc_testnet') {
    NEW_OWNER = process.env.OWNER || deployer.address
    PROXY_ADMIN_OWNER = process.env.PROXY_ADMIN_OWNER || deployer.address
    console.log('Deploying on BSC Testnet', hre.network.name, 'Network', deployer.address)
    oracleInitializeArgs = ['0x79e9675cDe605Ef9965AbCE185C5FD08d0DE16B1'];
    // testnet token address
    tokenAddress = '0xb77380b3d7E384Aa05477A7eEAEd4db3420216f1'
  }

  // add collateral
  await addCollateral_Origin({
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
