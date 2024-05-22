const fs = require('fs')
const path = require('path')
const {ethers, upgrades} = require('hardhat')
const {transferProxyAdminOwner} = require('../upgrades/utils/upgrade_utils')
const contractAddresses = require('../deploy/contract_address.json');

// Global Variables
let rad = '000000000000000000000000000000000000000000000' // 45 Decimals

module.exports.addCollateral = async function (opts) {
  const {
    symbol,
    tokenAddress,
    oracleName = 'BtcOracle',
    oracleInitializeArgs = [],
    oracleInitializer = 'initialize',
    owner,
    proxyAdminOwner,
    clipperBuf = '1100000000000000000000000000',
    clipperTail = '10800',
    clipperCusp = '600000000000000000000000000',
    clipperChip = '0',
    clipperTip = '5' + rad,
    clipperStopped = '0'
  } = opts;

  const {
    VAT,
    DOG,
    SPOT,
    INTERACTION,
    VOW,
    ABACI,
    JUG
  } = (hre.network.name === 'bsc_testnet') ? contractAddresses["testnet"] : contractAddresses["mainnet"];


  [deployer] = await ethers.getSigners();
  let NEW_OWNER = owner || '0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37'
  let NEW_PROXY_ADMIN_OWNER = proxyAdminOwner || '0x08aE09467ff962aF105c23775B9Bc8EAa175D27F'

  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory('GemJoin')
  this.Clipper = await hre.ethers.getContractFactory('Clipper')
  this.Oracle = await hre.ethers.getContractFactory(oracleName)

  // Set addresses
  const ILK = ethers.encodeBytes32String(symbol)

  if (hre.network.name === 'bsc_testnet') {
    NEW_OWNER = owner || deployer.address
    NEW_PROXY_ADMIN_OWNER = proxyAdminOwner || deployer.address
  }

  // Deploy contracts
  const gemJoin = await upgrades.deployProxy(this.GemJoin, [VAT, ILK, tokenAddress])
  await gemJoin.waitForDeployment()
  let gemJoinImplementation = await upgrades.erc1967.getImplementationAddress(gemJoin.target)
  console.log('Deployed: gemJoin    : ' + gemJoin.target)
  console.log('Imp                  : ' + gemJoinImplementation)
  // transfer proxy admin ownership
  if (deployer.address !== NEW_PROXY_ADMIN_OWNER) {
    await transferProxyAdminOwner(gemJoin.target, NEW_PROXY_ADMIN_OWNER)
    console.log('Proxy Admin Ownership Of gemJoin Transferred to: ' + NEW_PROXY_ADMIN_OWNER)
  }

  const clipper = await upgrades.deployProxy(this.Clipper, [VAT, SPOT, DOG, ILK])
  await clipper.waitForDeployment()
  let clipperImplementation = await upgrades.erc1967.getImplementationAddress(clipper.target)
  console.log('Deployed: clipCE     : ' + clipper.target)
  console.log('Imp                  : ' + clipperImplementation)
  // transfer proxy admin ownership
  if (deployer.address !== NEW_PROXY_ADMIN_OWNER) {
    await transferProxyAdminOwner(clipper.target, NEW_PROXY_ADMIN_OWNER)
    console.log('Proxy Admin Ownership Of clipCE Transferred to: ' + NEW_PROXY_ADMIN_OWNER)
  }

  const oracle = await upgrades.deployProxy(this.Oracle, oracleInitializeArgs, {initializer: oracleInitializer})
  await oracle.waitForDeployment()
  let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target)
  console.log('Deployed: oracle     : ' + oracle.target)
  console.log('Imp                  : ' + oracleImplementation)
  // transfer proxy admin ownership
  if (deployer.address !== NEW_PROXY_ADMIN_OWNER) {
    await transferProxyAdminOwner(oracle.target, NEW_PROXY_ADMIN_OWNER)
    console.log('Proxy Admin Ownership Of Oracle Transferred to: ' + NEW_PROXY_ADMIN_OWNER)
  }

  // Initialize
  await gemJoin.rely(INTERACTION)

  await clipper.rely(DOG)
  await clipper.rely(INTERACTION)
  await clipper['file(bytes32,uint256)'](ethers.encodeBytes32String('buf'), clipperBuf) // 10%
  await clipper['file(bytes32,uint256)'](ethers.encodeBytes32String('tail'), clipperTail) // 3h reset time
  await clipper['file(bytes32,uint256)'](ethers.encodeBytes32String('cusp'), clipperCusp) // 60% reset ratio
  await clipper['file(bytes32,uint256)'](ethers.encodeBytes32String('chip'), clipperChip) // 0.01% from vow incentive
  await clipper['file(bytes32,uint256)'](ethers.encodeBytes32String('tip'), clipperTip) // 10$ flat fee incentive
  await clipper['file(bytes32,uint256)'](ethers.encodeBytes32String('stopped'), clipperStopped)

  await clipper['file(bytes32,address)'](ethers.encodeBytes32String('spotter'), SPOT)
  await clipper['file(bytes32,address)'](ethers.encodeBytes32String('dog'), DOG)
  await clipper['file(bytes32,address)'](ethers.encodeBytes32String('vow'), VOW)
  await clipper['file(bytes32,address)'](ethers.encodeBytes32String('calc'), ABACI)

  // Transfer Ownerships
  await gemJoin.rely(NEW_OWNER)
  await clipper.rely(NEW_OWNER)

  if (deployer.address !== NEW_OWNER) {
    await gemJoin.deny(deployer.address)
    await clipper.deny(deployer.address)
  }

  console.log('token address: ' + tokenAddress)
  console.log(ILK)

  // Store deployed addresses
  const addresses = {
    symbol,
    tokenAddress,
    ilk: ILK,
    gemJoin: gemJoin.target,
    gemJoinImplementation: gemJoinImplementation,
    clipper: clipper.target,
    clipperImplementation: clipperImplementation,
    oracle: oracle.target,
    oracleImplementation: oracleImplementation,
    oracleInitializeArgs,
    owner: NEW_OWNER,
    proxyAdminOwner: NEW_PROXY_ADMIN_OWNER,
  }

  const json_addresses = JSON.stringify(addresses)
  console.log('json addresses: ', json_addresses)
  const dir = path.join(__dirname, `../../addresses/new_collateral_${symbol}_${hre.network.name}.json`)
  fs.writeFileSync(dir, json_addresses)
  console.log('Addresses Recorded to: ' + dir)

  // Verify
  await hre.run('verify:verify', {address: gemJoin.target})
  await hre.run('verify:verify', {address: clipper.target})
  await hre.run('verify:verify', {address: oracle.target})

  // await hre.run('verify:verify', {address: gemJoinImplementation})
  // await hre.run('verify:verify', {address: clipperImplementation})
  // await hre.run('verify:verify', {address: oracleImplementation, contract: 'contracts/oracle/BtcOracle.sol:BtcOracle'})
}
