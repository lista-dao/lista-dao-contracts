const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
let X_SOLV_BTC_ETH_PRICE_FEED = "0x24c8964338Deb5204B096039147B8e8C3AEa42Cc"

async function main() {
  console.log(`[xSolvBTC Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('xSolvBtcPriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE, X_SOLV_BTC_ETH_PRICE_FEED);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[xSolvBTC Price Feed] Deployed to:', address);

  console.log(`[xSolvBTC Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE, X_SOLV_BTC_ETH_PRICE_FEED]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
