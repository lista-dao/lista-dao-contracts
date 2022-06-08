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
    VOW, COLLATERAL_CE_ABNBC,
    INTERACTION, REAL_ABNBC, REWARDS, DOG
} = require('../../addresses-stage2.json');
const {ethers} = require("hardhat");

async function main() {
    console.log('Running deploy script');

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    // this.Usb = await hre.ethers.getContractFactory("Usb");
    // this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    // this.UsbJoin = await hre.ethers.getContractFactory("UsbJoin");
    // this.Oracle = await hre.ethers.getContractFactory("Oracle");
    // this.Jug = await hre.ethers.getContractFactory("Jug");
    // this.Interaction = await hre.ethers.getContractFactory("Interaction");
    // this.Clip = await hre.ethers.getContractFactory("Clipper");

    let vat = this.Vat.attach(VAT);
    await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("dust"), "1" + ray);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
