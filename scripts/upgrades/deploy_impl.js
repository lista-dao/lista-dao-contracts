const {ethers} = require('hardhat')
const {deployImplementation, verifyImpContract} = require('./utils/upgrade_utils')

const contractName = 'CerosETHRouter'


async function main() {
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
