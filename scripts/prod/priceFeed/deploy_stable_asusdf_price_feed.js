const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

const RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
const ASUSDF_EARN = "0xdB57a53C428a9faFcbFefFB6dd80d0f427543695"

async function main() {
  const StableASUSDFPriceFeed = await hre.ethers.getContractFactory('StableAsUsdfPriceFeed');
  const stableAsusdfPriceFeed = await upgrades.deployProxy(StableASUSDFPriceFeed, [RESILIENT_ORACLE, ASUSDF_EARN]);
  await stableAsusdfPriceFeed.waitForDeployment();

  console.log('StableAsusdfPriceFeed deployed to:', stableAsusdfPriceFeed.target);
  // verify contract
  await run("verify:verify", {
    address: stableAsusdfPriceFeed.target,
    constructorArguments: [],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
