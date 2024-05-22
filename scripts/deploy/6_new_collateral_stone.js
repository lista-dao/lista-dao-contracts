const fs = require('fs')
const path = require('path')
const {ethers, upgrades} = require('hardhat')
const {addCollateral} = require('../utils/add_collateral')

// Global Variables
let rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()
  let NEW_OWNER = '0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37'
  let PROXY_ADMIN_OWNER = '0x08aE09467ff962aF105c23775B9Bc8EAa175D27F'

  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory('GemJoin')
  this.Clipper = await hre.ethers.getContractFactory('Clipper')

  const symbol = 'STONE'
  let tokenAddress = '0x80137510979822322193fc997d400d5a6c747bf7'
  let oracleName = 'StoneOracle';
  let oracleInitializeArgs = [
    '0xADCc15cE3900A2Fc8544e26fD89897C0484e98Fc', // STONE/ETH price feed of api3
    '0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e' // ETH/USD price feed of chain link
  ];
  let oracleInitializer = 'initialize';

  if (hre.network.name === 'bsc_testnet') {
    oracleName = 'StoneOracleDev'
    NEW_OWNER = process.env.OWNER || deployer.address
    PROXY_ADMIN_OWNER = process.env.PROXY_ADMIN_OWNER || deployer.address
    console.log('Deploying on BSC Testnet', hre.network.name, 'Network', deployer.address)
    // deploy token
    const ERC20UpgradeableMock = await hre.ethers.getContractFactory('ERC20UpgradeableMock')
    const tokenMock = await upgrades.deployProxy(ERC20UpgradeableMock, [symbol, symbol])
    await tokenMock.waitForDeployment()
    const tokenMockImplementation = await upgrades.erc1967.getImplementationAddress(tokenMock.target)
    console.log('Deployed: clipCE     : ' + tokenMock.target)
    console.log('Imp                  : ' + tokenMockImplementation)
    tokenAddress = await tokenMock.target
    // await hre.run('verify:verify', {address: tokenMock.target})
    // await hre.run('verify:verify', {address: tokenMockImplementation, contract: 'contracts/mock/ERC20UpgradeableMock.sol:ERC20UpgradeableMock'})
    // mint 10000000 tokens to deployer
    await tokenMock.mint(deployer.address, ethers.parseEther('10000000'))

    // mock price feed
    oracleInitializeArgs = ['0x335d1C771d87abf679b56d6573F48896D805114d', '0x635780E5D02Ab29d7aE14d266936A38d3D5B0CC5'];
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
