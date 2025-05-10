const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

const RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
const STAKE_MANAGER = "0x1adB950d8bB3dA4bE104211D5AB038628e477fE6"

async function main() {
  console.log(`[slisBNB Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('SlisBnbPriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE, STAKE_MANAGER);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[slisBNB Price Feed] Deployed to:', address);

  console.log(`[slisBNB Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE, STAKE_MANAGER]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
