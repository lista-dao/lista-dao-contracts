const {ethers, upgrades} = require('hardhat')
const {deployImplementation, verifyImpContract} = require('./utils/upgrade_utils')

const oldContractAddress = ''
const oldContractName = ''
const contractName = 'mwBETHOracle'


async function main() {
  if (oldContractName && oldContractAddress) {
    console.log('Validate if its upgradable...');
    const contractFactory = await ethers.getContractFactory(contractName);
    const oldContractFactory = await ethers.getContractFactory(oldContractName);
    await upgrades.forceImport(oldContractAddress, oldContractFactory, { kind: 'transparent' });
    await upgrades.validateUpgrade(oldContractAddress, contractFactory)
    console.log('Updatability is validated successfully.');
  }

  console.log('Running deploy script')

  console.log(`Deploy ${contractName}...`)
  const interactionAddress = await deployImplementation(contractName)
  console.log(`${contractName} deployed to:`, interactionAddress)


  await verifyImpContract(interactionAddress)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
