const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
let PUFETH_ETH_PRICE_FEED = "0xCa8b247304767619fCcF5b0829D0a5AAf414BA7D"

async function main() {
  console.log(`[pufETH Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('PufETHPriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE, PUFETH_ETH_PRICE_FEED);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[pufETH Price Feed] Deployed to:', address);

  console.log(`[pufETH Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE, PUFETH_ETH_PRICE_FEED]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
