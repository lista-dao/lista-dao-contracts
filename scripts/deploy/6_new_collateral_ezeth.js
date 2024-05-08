const fs = require('fs')
const path = require('path')
const {ethers, upgrades} = require('hardhat')
const {addCollateral} = require('../utils/add_collateral_ezeth')

// Global Variables
let rad = '000000000000000000000000000000000000000000000' // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners()
  let NEW_OWNER = '0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37'

  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory('GemJoin')
  this.Clipper = await hre.ethers.getContractFactory('Clipper')
  this.Oracle = await hre.ethers.getContractFactory('BtcOracle')

  const symbol = 'ezETH'
  let tokenAddress = '0x2416092f143378750bb29b79ed961ab195cceea5'
  // Binance Oracle ezeth Aggregator Address
  let priceFeed = '0x763c59a3D23936CD7B73571112744f2cFc2537F8'

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
    //await hre.run('verify:verify', {address: tokenMockImplementation, contract: 'contracts/mock/ERC20UpgradeableMock.sol:ERC20UpgradeableMock'})
    // mint 10000000 tokens to deployer
    await tokenMock.mint(deployer.address, ethers.parseEther('10000000'))
    priceFeed = '0xc0e60De0CB09a432104C823D3150dDEEA90E8f7d'
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
