const hre = require("hardhat");

const {
    ceBNBc, DEPLOYER, COLLATERAL_CE_ABNBC
} = require('../../addresses-stage2.json');
const {ethers, upgrades} = require("hardhat");


async function main() {
    console.log('Running deploy script');

    let collateral = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Hay = await hre.ethers.getContractFactory("Hay");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.HayJoin = await hre.ethers.getContractFactory("HayJoin");
    // this.Oracle = await hre.ethers.getContractFactory("Oracle"); // Mock Oracle
    this.Jug = await hre.ethers.getContractFactory("Jug");
    // this.Vow = await hre.ethers.getContractFactory("Vow");
    // this.Jar = await hre.ethers.getContractFactory("Jar");
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Clip = await hre.ethers.getContractFactory("Clipper");

    const vat = await upgrades.deployProxy(this.Vat, []);
    console.log("Vat deployed to:", vat.address);

    const spot = await this.Spot.deploy(vat.address);
    await spot.deployed();
    console.log("Spot deployed to:", spot.address);

    const hay = await this.Hay.deploy(97, "HAY");
    await hay.deployed();
    console.log("Hay deployed to:", hay.address);

    const hayJoin = await this.HayJoin.deploy(vat.address, hay.address);
    await hayJoin.deployed();
    console.log("hayJoin deployed to:", hayJoin.address);

    const bnbJoin = await this.GemJoin.deploy(vat.address, collateral, ceBNBc);
    await bnbJoin.deployed();
    console.log("bnbJoin deployed to:", bnbJoin.address);

    const jug = await this.Jug.deploy(vat.address);
    await jug.deployed();
    console.log("Jug deployed to:", jug.address);

    const vow = await this.Vow.deploy(vat.address, ethers.constants.AddressZero, ethers.constants.AddressZero, DEPLOYER);
    await vow.deployed();
    console.log("Vow deployed to:", vow.address);

    const dog = await this.Dog.deploy(vat.address);
    await dog.deployed();
    console.log("Dog deployed to:", dog.address);

    const clip = await this.Clip.deploy(vat.address, spot.address, dog.address, collateral);
    await clip.deployed();
    console.log("Clip deployed to:", clip.address);

    console.log('Validating code');
    await hre.run("verify:verify", {
        address: vat.address
    });
    await hre.run("verify:verify", {
        address: spot.address,
        constructorArguments: [
            vat.address
        ],
    });
    await hre.run("verify:verify", {
        address: hayJoin.address,
        constructorArguments: [
            vat.address,
            hay.address,
        ],
    });
    await hre.run("verify:verify", {
        address: bnbJoin.address,
        constructorArguments: [
            vat.address,
            collateral,
            ceBNBc,
        ],
    });
    await hre.run("verify:verify", {
        address: jug.address,
        constructorArguments: [
            vat.address
        ],
    });
    await hre.run("verify:verify", {
        address: vow.address,
        constructorArguments: [
            vat.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            DEPLOYER
        ],
    });
    await hre.run("verify:verify", {
        address: dog.address,
        constructorArguments: [
            vat.address
        ],
    });
    await hre.run("verify:verify", {
        address: clip.address,
        constructorArguments: [
            vat.address,
            spot.address,
            dog.address,
            collateral
        ],
    });
    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });