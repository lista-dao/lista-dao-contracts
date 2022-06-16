const hre = require("hardhat");

const {
    ceBNBc, DEPLOYER, COLLATERAL_CE_ABNBC,
    Oracle, HELIO_PROVIDER, VAT,
    ABACI, SPOT, DOG, VOW, CLIP,
} = require('../../addresses-stage2.json');
const {ethers, upgrades} = require("hardhat");
const {BN, ether} = require("@openzeppelin/test-helpers");

let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {
    console.log('Running deploy script');

    let collateral = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);
    console.log("Ilk: " + collateral);

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Hay = await hre.ethers.getContractFactory("Hay");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.HayJoin = await hre.ethers.getContractFactory("HayJoin");
    // this.Oracle = await hre.ethers.getContractFactory("Oracle"); // Mock Oracle
    this.Jug = await hre.ethers.getContractFactory("Jug");
    this.Vow = await hre.ethers.getContractFactory("Vow");
    // this.Jar = await hre.ethers.getContractFactory("Jar");
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Clip = await hre.ethers.getContractFactory("Clipper");

    this.HelioToken = await hre.ethers.getContractFactory("HelioToken");
    this.HelioRewards = await hre.ethers.getContractFactory("HelioRewards");
    this.HelioOracle = await hre.ethers.getContractFactory("HelioOracle");

    this.AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");

    console.log("Deploying core contracts");

    let vat = this.Vat.attach(VAT);
    let dog = this.Dog.attach(DOG);

    const vow = await this.Vow.deploy(VAT, ethers.constants.AddressZero, ethers.constants.AddressZero, DEPLOYER);
    await vow.deployed();
    console.log("Vow deployed to:", vow.address);

    console.log("Core contracts auth");

    await vat.rely(vow.address);
    await dog.rely(vow.address);
    await vow.rely(dog.address);

    await dog["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
