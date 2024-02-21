const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

async function main() {

  // Constant Addresses
  let hay = "0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5",
      operator = "0x57F9672bA603251C9C03B36cabdBBcA7Ca8Cfcf4",
      exitDelay = "1209600", // 14 Days
      spread = "1209600", // 14 Days
      flashLoanDelay = "5"; // 5 Seconds

  // Script variables
  let jar;

  // Contracts Fetching
  this.Jar = await hre.ethers.getContractFactory("Jar");

  // Jar Deployment
  console.log("Jar...")

  jar = await upgrades.deployProxy(this.Jar, ["HelioHay", "hHAY", hay, spread, exitDelay, flashLoanDelay]);
  await jar.waitForDeployment();
  let jarImplementation = await upgrades.erc1967.getImplementationAddress(jar.target);
  console.log("Deployed: jar        : " + jar.target);
  console.log("Imp                  : " + jarImplementation);

  // Jar Init
  await jar.addOperator(operator);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });