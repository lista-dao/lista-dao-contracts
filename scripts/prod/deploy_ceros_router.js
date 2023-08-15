const hre = require("hardhat");
const {ethers, upgrades} = require("hardhat");
require("@nomiclabs/hardhat-etherscan");

// const {
//     VAT,
//     SPOT,
//     USB,
//     UsbJoin,
//     JUG,
//     REWARDS,
//     DOG, DEPLOYER,
// } = require('../../addresses-stage2.json');

async function main() {
    console.log('Running deploy script');

    let Contract = await hre.ethers.getContractFactory("CerosRouter");
    const contract = await Contract.deploy();
    await contract.deployed();

    console.log(`CerosRouter deployed to:`, contract.address);

    await hre.run("verify:verify", {
        address: contract.address,
    });

    let VaultContract = await hre.ethers.getContractFactory("CeVault");
    const vaultContract = await VaultContract.deploy();
    await vaultContract.deployed();

    console.log(`CerosVault deployed to:`, vaultContract.address);

    await hre.run("verify:verify", {
        address: vaultContract.address,
    });

    let ProviderContract = await hre.ethers.getContractFactory("HelioProvider");
    const providerContract = await ProviderContract.deploy();
    await providerContract.deployed();

    console.log(`HelioProvider deployed to:`, providerContract.address);

    await hre.run("verify:verify", {
        address: providerContract.address,
    });


    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
