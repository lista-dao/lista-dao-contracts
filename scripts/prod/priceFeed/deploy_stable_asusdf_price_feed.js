const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')
const {deployImplementation, verifyImpContract} = require("../../upgrades/utils/upgrade_utils");

const RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
const ASUSDF_EARN = "0xdB57a53C428a9faFcbFefFB6dd80d0f427543695"

async function main() {
  console.log(`[Stable AsUSDF Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('StableAsUsdfPriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE, ASUSDF_EARN);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[Stable AsUSDF Price Feed] Deployed to:', address);

  console.log(`[Stable AsUSDF Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE, ASUSDF_EARN]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
