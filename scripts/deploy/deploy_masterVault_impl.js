const hre = require("hardhat");
const {ethers, upgrades} = require("hardhat");

async function main() {

    const Contract = await hre.ethers.getContractFactory('MasterVault');

    console.log(`Deploying MasterVault`);
    const contract = await Contract.deploy();

    await contract.waitForDeployment();

    console.log(`MasterVault deployed to:`, contract.target);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
