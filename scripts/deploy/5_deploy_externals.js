const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");
const {ether} = require("@openzeppelin/test-helpers");

async function main() {

  // Constant Addresses
  let hay = "",
      exitDelay = "1209600", // 14 Days
      spread = "1209600", // 14 Days
      flashLoanDelay = "5"; // 5 Seconds

  // Script variables
  let jar;

  // Contracts Fetching
  this.Jar = await hre.ethers.getContractFactory("Jar");

  // Jar Deployment
  console.log("Jar...") 

  jar = await upgrades.deployProxy(this.Jar, ["HelioHay", "hHAY", hay, spread, exitDelay, flashLoanDelay], {initializer: "initialize"});
  await jar.deployed();
  let jarImplementation = await upgrades.erc1967.getImplementationAddress(jar.address);
  console.log("Deployed: jar        : " + jar.address);
  console.log("Imp                  : " + jarImplementation);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });