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
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    // this.Usb = await hre.ethers.getContractFactory("Usb");
    // this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    // this.UsbJoin = await hre.ethers.getContractFactory("UsbJoin");
    // this.Oracle = await hre.ethers.getContractFactory("Oracle");
    // this.Jug = await hre.ethers.getContractFactory("Jug");
    // this.Interaction = await hre.ethers.getContractFactory("Interaction");
    // this.Clip = await hre.ethers.getContractFactory("Clipper");
    console.log("Dog...");

    let dog = this.Dog.attach(DOG);
    // await dog["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Hole"), "500" + rad);
    // await dog["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);
    await dog["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("hole"), "500" + rad);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
