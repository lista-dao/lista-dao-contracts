const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

const RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"

async function main() {
  const StableUSDTPriceFeed = await hre.ethers.getContractFactory('StableUsdtPriceFeed');
  const stableUsdtPriceFeed = await upgrades.deployProxy(StableUSDTPriceFeed, [RESILIENT_ORACLE]);
  await stableUsdtPriceFeed.waitForDeployment();

  console.log('StableUsdtPriceFeed deployed to:', stableUsdtPriceFeed.target);
  // verify contract
  await run("verify:verify", {
    address: stableUsdtPriceFeed.target,
    constructorArguments: [],
  });

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
