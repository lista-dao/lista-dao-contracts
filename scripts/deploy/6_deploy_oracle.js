const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

async function main() {
    this.Oracle = await hre.ethers.getContractFactory("BnbOracle");
    
    let aggregatorAddress;
    if (hre.network.name == "bsc") {
        aggregatorAddress = "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE";
    } else if (hre.network.name == "bsc_testnet") {
        aggregatorAddress = "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526";
    }

    const oracle = await upgrades.deployProxy(this.Oracle, [aggregatorAddress], {initializer: "initialize"});
    await oracle.deployed();
    let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.address);
    console.log("Deployed: oracle     : " + oracle.address);
    console.log("Imp                  : " + oracleImplementation);

    // verify
    await hre.run("verify:verify", {address: oracleImplementation});
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});