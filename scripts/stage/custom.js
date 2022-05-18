const hre = require("hardhat");

const { VAT,
    SPOT,
    aBNBc,
    USB,
    UsbJoin,
    aBNBcJoin,
    REALaBNBcJoin,
    REALOracle,
    JUG,
    Oracle,
    VOW,
    INTERACTION, REAL_ABNBC, REWARDS, DOG,
    COLLATERAL_ABNBC,
    COLLATERAL_REAL_ABNBC,
    COLLATERAL_CE_ABNBC,
} = require('../../addresses.json');
const {ethers} = require("hardhat");

async function main() {
    console.log('Running deploy script');

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String(COLLATERAL_REAL_ABNBC);

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Usb = await hre.ethers.getContractFactory("Usb");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.UsbJoin = await hre.ethers.getContractFactory("UsbJoin");
    this.Oracle = await hre.ethers.getContractFactory("Oracle");
    this.Jug = await hre.ethers.getContractFactory("Jug");
    this.Interaction = await hre.ethers.getContractFactory("DAOInteraction");
    this.Clip = await hre.ethers.getContractFactory("Clipper");
    this.Rewards = await hre.ethers.getContractFactory("HelioRewards");

    let rewards = this.Jug.attach(REWARDS);

    await rewards.initPool(REAL_ABNBC, collateral, "1000000001847694957439350500"); //6%
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
