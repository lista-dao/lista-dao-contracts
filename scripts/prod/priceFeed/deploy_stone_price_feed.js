const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
let STONE_ETH_PRICE_FEED = "0x109A9AC63e6161B1818Faa2e902850997391bc1e"

async function main() {
  console.log(`[Stone Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('StonePriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE, STONE_ETH_PRICE_FEED);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[Stone Price Feed] Deployed to:', address);

  console.log(`[Stone Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE, STONE_ETH_PRICE_FEED]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
