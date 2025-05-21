const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"

async function main() {
  console.log(`[wBETH Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('WBETHPriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[wBETH Price Feed] Deployed to:', address);

  console.log(`[wBETH Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
