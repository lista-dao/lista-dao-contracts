const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

const RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
// https://data.chain.link/feeds/bsc/mainnet/stone-eth-exchange-rate
const STONE_ETH_PRICE_FEED = "0xC6A1314E89d01517a90AE4b0d9d5e499A324B283"

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
