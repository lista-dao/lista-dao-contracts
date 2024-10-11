const path = require('path')
const hre = require('hardhat')
const {ethers, upgrades} = require('hardhat')
const {deployImplementation, verifyImpContract} = require('../upgrades/utils/upgrade_utils')

const filePath = hre.network.name === 'bsc_testnet' ? path.join(process.cwd(), 'addresses/bsc_testnet.json') : path.join(process.cwd(), 'addresses/bsc.json')
let { interaction, auctionProxy } = require(filePath);
const oldContractName = 'InteractionV3'
const contractName = 'Interaction'
const resetAuctionProxy = false


async function main() {
  console.log('Running deploy script')

  if (resetAuctionProxy) {
    console.log('Deploying AuctionProxy...')
    const AuctionProxy = await ethers.getContractFactory('AuctionProxy')
    const auctionProxyContract = await AuctionProxy.deploy()
    await auctionProxyContract.waitForDeployment()
    console.log('AuctionProxy deployed to:', auctionProxyContract.address)
    auctionProxy = auctionProxyContract.address
  }

  const Interaction = await ethers.getContractFactory(contractName, {
    unsafeAllow: ['external-library-linking'],
    libraries: {
      AuctionProxy: auctionProxy,
    },
  })

  console.log('Validate if its upgradable...')
  const OldInteraction = await ethers.getContractFactory(oldContractName, {
    unsafeAllow: ['external-library-linking'],
    libraries: {
      AuctionProxy: auctionProxy,
    },
  });
  await upgrades.forceImport(interaction, OldInteraction, { kind: 'transparent' });
  await upgrades.validateUpgrade(interaction, Interaction, { unsafeAllow: ['external-library-linking'] })
  console.log('Updatability is validated successfully.')


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
