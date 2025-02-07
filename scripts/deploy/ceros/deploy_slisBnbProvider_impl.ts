const hre = require("hardhat");
const {ethers} = hre;

async function main() {
  const SlisBNBProvider = await ethers.getContractFactory('SlisBNBProvider');
  const _provider = await SlisBNBProvider.deploy();
  await _provider.waitForDeployment();
  const _providerAddress = await _provider.getAddress();
  console.log('contract deployed at: ', _providerAddress);
  // waiting for ~5 blocks, in case scan doesn't sync in time
  await new Promise((resolve) => setTimeout(resolve, 3000 * 5));
  console.log('---------- verifying contract ----------')
  await hre.run("verify:verify", {
    address: _providerAddress,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
