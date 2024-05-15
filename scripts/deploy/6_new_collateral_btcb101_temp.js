const fs = require('fs')
const path = require('path')
const {ethers, upgrades} = require('hardhat')
const {addCollateral} = require('../utils/add_collateral')

// Global Variables
let rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()
  let NEW_OWNER = '0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37'

  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory('GemJoin')
  this.Clipper = await hre.ethers.getContractFactory('Clipper')
  this.Oracle = await hre.ethers.getContractFactory('BtcOracle')

  const symbol = 'BTCB101'
  let tokenAddress = '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c'
  // Binance Oracle BTCB Aggregator Address
  let priceFeed = '0x83968bCa5874D11e02fD80444cDDB431a1DbEc0f'

  if (hre.network.name === 'bsc_testnet') {
    NEW_OWNER = deployer.address
    console.log('Deploying on BSC Testnet', hre.network.name, 'Network', deployer.address)
    // deploy token
    const ERC20UpgradeableMock = await hre.ethers.getContractFactory('ERC20UpgradeableMock')
    const tokenMock = await upgrades.deployProxy(ERC20UpgradeableMock, [symbol, symbol])
    await tokenMock.waitForDeployment()
    const tokenMockImplementation = await upgrades.erc1967.getImplementationAddress(tokenMock.target)
    console.log('Deployed: clipCE     : ' + tokenMock.target)
    console.log('Imp                  : ' + tokenMockImplementation)
    tokenAddress = await tokenMock.target
    await hre.run('verify:verify', {address: tokenMock.target})
    await hre.run('verify:verify', {address: tokenMockImplementation, contract: 'contracts/mock/ERC20UpgradeableMock.sol:ERC20UpgradeableMock'})
    // mint 10000000 tokens to deployer
    await tokenMock.mint(deployer.address, ethers.parseEther('10000000'))
    priceFeed = '0x491fD333937522e69D1c3FB944fbC5e95eEF9f59'
  }

  // add collateral
  await addCollateral({
    symbol,
    tokenAddress,
    priceFeed,
    owner: NEW_OWNER,
    clipperBuf: '1100000000000000000000000000',
    clipperTail: '10800',
    clipperCusp: '600000000000000000000000000',
    clipperChip: '100000000000000',
    clipperTip: '10' + rad,
    clipperStopped: '0'
  })
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
