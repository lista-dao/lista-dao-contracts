const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");
// const {ether} = require("@openzeppelin/test-helpers");

async function main() {

    // Constant Addresses
    let hay = "0x785b5d1Bde70bD6042877cA08E4c73e0a40071af",
        operator = "0x0C6f6b0C6f78950445133FADe7DECD64c0bDd093",
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
    await jar.waitForDeployment()
    let jarImplementation = await upgrades.erc1967.getImplementationAddress(jar.target);
    console.log("Deployed: jar        : " + jar.target);
    console.log("Imp                  : " + jarImplementation);


    await hre.run('verify:verify', {address: jar.target})

    // Jar Init
    await jar.addOperator(operator);


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
