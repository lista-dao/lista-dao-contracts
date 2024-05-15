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

  const symbol = 'weETH'
  let tokenAddress = '0x20cFB850133a98B2516389b04D33C92377B6772A'
  let oracleName = 'WeEthOracle';
  let oracleInitializeArgs = [
    '0x9b2C948dbA5952A1f5Ab6fA16101c1392b8da1ab', //weETH/eETH price feed of red stone
    '0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e' // ETH/USD price feed of chain link
  ];
  let oracleInitializer = 'initialize';

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
    //await hre.run('verify:verify', {address: tokenMock.target})
    //await hre.run('verify:verify', {address: tokenMockImplementation, contract: 'contracts/mock/ERC20UpgradeableMock.sol:ERC20UpgradeableMock'})
    // mint 10000000 tokens to deployer
    await tokenMock.mint(deployer.address, ethers.parseEther('10000000'))

    // testnet oracle name
    // oracleName = 'BtcOracle'
    // todo: replace the price feeds with testnet price feeds
    oracleInitializeArgs = [
      '0x77D231e51614C84e15CCC38E2a52BFab49D6853C',
      '0x635780E5D02Ab29d7aE14d266936A38d3D5B0CC5'
    ];
  }

  // add collateral
  await addCollateral({
    symbol,
    tokenAddress,
    oracleName,
    oracleInitializeArgs,
    oracleInitializer,
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
