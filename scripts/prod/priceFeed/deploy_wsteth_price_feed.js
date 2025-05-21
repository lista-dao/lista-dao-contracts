const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
let WSTETH_ETH_PRICE_FEED = "0xE7e734789954e6CffD8C295CBD0916A0A5747D27"

async function main() {
  console.log(`[wstETH Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('WstETHPriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE, WSTETH_ETH_PRICE_FEED);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[wstETH Price Feed] Deployed to:', address);

  console.log(`[wstETH Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE, WSTETH_ETH_PRICE_FEED]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
