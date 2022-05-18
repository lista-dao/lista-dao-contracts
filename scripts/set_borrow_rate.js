const {BN} = require("@openzeppelin/test-helpers");
const {JUG} = require("../addresses.json");
const {ethers} = require("hardhat");
const hre = require("hardhat");

async function main() {
    console.log('Running deploy script');

    this.Jug = await hre.ethers.getContractFactory("Jug");
    // let BR = new BN("1000000604453200000000000000").toString(); //2000% APY
    let BR = new BN("1000000003022266000000000000").toString(); //10% APY
    let jug = this.Jug.attach(JUG);
    await jug["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), BR);

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

