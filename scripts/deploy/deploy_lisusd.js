const hre = require("hardhat");
const {upgrades} = require("hardhat");

async function main() {
  // Contracts Fetching
  this.Hay = await hre.ethers.getContractFactory("Hay");
  this.LisUSD = await hre.ethers.getContractFactory("LisUSD");

   // check whether the LisUSD is compatible with the Hay
  await upgrades.validateUpgrade(this.Hay, this.LisUSD);
  console.log("LisUSD is compatible with Hay, can be upgraded to.")

  const lisUSD = await this.LisUSD.deploy();
  console.log("Deployed: LisUSD        : " + lisUSD.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
