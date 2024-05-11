const hre = require('hardhat')
const {ethers, upgrades} = require('hardhat')
const {deployImplementation, verifyImpContract} = require('./utils/upgrade_utils')

const proxyAddress = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
const auctionProxy = '0x272d6589CEcC19165cfCd0466f73A648cb1Ea700'
const contractName = 'Interaction'


async function main() {
  console.log('Running deploy script')

  const Interaction = await ethers.getContractFactory('Interaction', {
    unsafeAllow: ['external-library-linking'],
    libraries: {
      AuctionProxy: auctionProxy,
    },
  })

  console.log('Validate if its upgradable...')
  const InteractionV1 = await ethers.getContractFactory('InteractionV1', {
    unsafeAllow: ['external-library-linking'],
    libraries: {
      AuctionProxy: auctionProxy,
    },
  });
  await upgrades.forceImport(proxyAddress, InteractionV1, { kind: 'transparent' });
  await upgrades.validateUpgrade(proxyAddress, Interaction, { unsafeAllow: ['external-library-linking'] })
  console.log('Upgradability is validated successfully.')


  console.log('Deploy Interaction...')
  const interactionAddress = await deployImplementation(contractName, {
    unsafeAllow: ['external-library-linking'],
    libraries: {
      AuctionProxy: auctionProxy,
    },
  })

  console.log('Interaction deployed to:', interactionAddress)


  await verifyImpContract(interactionAddress)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
