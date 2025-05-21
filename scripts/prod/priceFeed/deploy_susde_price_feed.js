const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

const RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
// https://data.chain.link/feeds/bsc/mainnet/susde-usde-exchange-rate
const sUSDe_USDe_PRICE_FEED = "0x1a269eA1b209DA2c12bDCDab22635C9e6C5028B2"

async function main() {
  console.log(`[sUSDe Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('sUSDePriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE, sUSDe_USDe_PRICE_FEED);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[sUSDe Price Feed] Deployed to:', address);

  console.log(`[sUSDe Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE, sUSDe_USDe_PRICE_FEED]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
