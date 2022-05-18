const hre = require("hardhat");

const { VAT,
    SPOT,
    aBNBc,
    REAL_ABNBC,
    USB,
    UsbJoin,
    aBNBcJoin,
    REALaBNBcJoin,
    Oracle,
    REALOracle,
    JUG,
    VOW,
    INTERACTION,
    REWARDS,
    CLIP1,
    CLIP2
} = require('../../addresses.json');
const {ethers} = require("hardhat");
const {BN} = require("@openzeppelin/test-helpers");

async function main() {
    console.log('Running deploy script');

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("aBNBc");
    let collateral2 = ethers.utils.formatBytes32String("aBNBc2");

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Usb = await hre.ethers.getContractFactory("Usb");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.UsbJoin = await hre.ethers.getContractFactory("UsbJoin");
    this.Oracle = await hre.ethers.getContractFactory("Oracle");
    this.Interaction = await hre.ethers.getContractFactory("DAOInteraction");
    this.Jug = await hre.ethers.getContractFactory("Jug");

    console.log("Setting permissions");

    // let oracle = this.Oracle.attach(Oracle);
    // let oracle2 = this.Oracle.attach(REALOracle);
    // await oracle.setPrice("400" + wad); // 2$, mat = 80%, 2$ * 80% = 1.6$ With Safety Margin
    // await oracle2.setPrice("300" + wad); // 400$, mat = 80%, 400$ * 80% = 320$ With Safety Margin

    console.log("Vat...");

    let vat = this.Vat.attach(VAT);
    await vat.rely(aBNBcJoin);
    await vat.rely(REALaBNBcJoin);
    await vat.rely(SPOT);
    await vat.rely(UsbJoin);
    await vat.rely(JUG);

    await vat.rely(INTERACTION);

    await vat["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "500000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray);
    await vat["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray);

    console.log("Spot...");
    let spot = this.Spot.attach(SPOT);
    await spot["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), Oracle);
    await spot["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio

    await spot["file(bytes32,bytes32,address)"](collateral2, ethers.utils.formatBytes32String("pip"), REALOracle);
    await spot["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio

    await spot["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // It means pegged to 1$
    await spot.poke(collateral);
    await spot.poke(collateral2);

    console.log("Jug...");
    let BR = new BN("1000000003022266000000000000").toString(); //10% APY
    let jug = this.Jug.attach(JUG);
    await jug["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), BR); // 10% Yearly
    await jug["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);

    console.log("Usb...");
    let usb = this.Usb.attach(USB);
    await usb.rely(UsbJoin);

    console.log("Interaction...");
    let interaction = this.Interaction.attach(INTERACTION);
    await interaction.setCollateralType(aBNBc, aBNBcJoin, collateral, CLIP1);
    await interaction.setCollateralType(REAL_ABNBC, REALaBNBcJoin, collateral2, CLIP2);
    // await interaction.enableCollateralType(aBNBc, aBNBcJoin, collateral);
    // await interaction.enableCollateralType(REAL_ABNBC, REALaBNBcJoin, collateral2);
    await interaction.drip(aBNBc);
    await interaction.drip(REAL_ABNBC);

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
