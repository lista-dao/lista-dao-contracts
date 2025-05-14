const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

// https://data.chain.link/feeds/bsc/mainnet/usde-usd
let USDe_USD_PRICE_FEED = "0x10402B01cD2E6A9ed6DBe683CbC68f78Ff02f8FC"
// https://data.chain.link/feeds/bsc/mainnet/susde-usde-exchange-rate
let sUSDe_USDe_PRICE_FEED = "0x1a269eA1b209DA2c12bDCDab22635C9e6C5028B2"

async function main() {
  console.log(`[sUSDe Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('sUSDePriceFeed');
  const contract = await factory.deploy(sUSDe_USDe_PRICE_FEED, USDe_USD_PRICE_FEED);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[sUSDe Price Feed] Deployed to:', address);

  console.log(`[sUSDe Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [sUSDe_USDe_PRICE_FEED, USDe_USD_PRICE_FEED]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
