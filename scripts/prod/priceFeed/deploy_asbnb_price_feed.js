const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let RESILIENT_ORACLE = "0xf3afD82A4071f272F403dC176916141f44E6c750"
let ASBNB_MINTER = "0x2F31ab8950c50080E77999fa456372f276952fD8"

if (hre.network.name !== 'bsc') {
  RESILIENT_ORACLE = "0x79e9675cDe605Ef9965AbCE185C5FD08d0DE16B1"
  ASBNB_MINTER = "0xb42096BCfdb216C89A314A011e3AFbb7Bab03d35"
}

async function main() {
  console.log(`[asBNB Price Feed] Deploying...`)
  const factory = await ethers.getContractFactory('AsBnbPriceFeed');
  const contract = await factory.deploy(RESILIENT_ORACLE, ASBNB_MINTER);
  await contract.deploymentTransaction().wait(6);
  const address = await contract.getAddress();
  console.log('[asBNB Price Feed] Deployed to:', address);

  console.log(`[asBNB Price Feed] Verifying...`)
  await hre.run("verify:verify", {address, constructorArguments: [RESILIENT_ORACLE, ASBNB_MINTER]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
