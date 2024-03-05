const {upgrades} = require("hardhat");

const proxyAddress = "";

async function main() {
  // Contracts Fetching
  this.Hay = await hre.ethers.getContractFactory("Hay");
  this.LisUSD = await hre.ethers.getContractFactory("LisUSD");

   // check whether the LisUSD is compatible with the Hay
  await upgrades.validateUpgrade(this.Hay, this.LisUSD);
  console.log("LisUSD is compatible with Hay, can be upgraded to.")

  await upgrades.upgradeProxy(proxyAddress, this.LisUSD);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
