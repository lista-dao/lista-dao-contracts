const fs = require('fs')
const path = require('path')
const {ethers, upgrades} = require('hardhat')
const {addCollateral} = require('../utils/add_collateral')

// Global Variables
let rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()
  let NEW_OWNER = '0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37'
  let PROXY_ADMIN_OWNER = '0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253'

  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory('GemJoin')
  this.Clipper = await hre.ethers.getContractFactory('Clipper')

  const symbol = 'BTCB'
  let tokenAddress = '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c'
  // chain link BTC/USD price feed
  let oracleName = 'BtcOracle';
  let oracleInitializeArgs = ['0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf'];
  let oracleInitializer = 'initialize';

  if (hre.network.name === 'bsc_testnet') {
    NEW_OWNER = process.env.OWNER || deployer.address
    PROXY_ADMIN_OWNER = process.env.PROXY_ADMIN_OWNER || deployer.address
    console.log('Deploying on BSC Testnet', hre.network.name, 'Network', deployer.address)
    // deploy token
    const ERC20UpgradeableMock = await hre.ethers.getContractFactory('ERC20UpgradeableMock')
    const tokenMock = await upgrades.deployProxy(ERC20UpgradeableMock, [symbol, symbol])
    await tokenMock.waitForDeployment()
    const tokenMockImplementation = await upgrades.erc1967.getImplementationAddress(tokenMock.target)
    console.log('Deployed: tokenMock     : ' + tokenMock.target)
    console.log('Imp                  : ' + tokenMockImplementation)
    tokenAddress = await tokenMock.target
    await hre.run('verify:verify', {address: tokenMock.target})
    await hre.run('verify:verify', {address: tokenMockImplementation, contract: 'contracts/mock/ERC20UpgradeableMock.sol:ERC20UpgradeableMock'})
    // mint 10000000 tokens to deployer
    await tokenMock.mint(deployer.address, ethers.parseEther('10000000'))
    oracleInitializeArgs = ['0x491fD333937522e69D1c3FB944fbC5e95eEF9f59'];
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
