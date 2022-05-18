const hre = require("hardhat");

const { VAT,
    SPOT,
    aBNBc,
    REAL_ABNBC,
    ceBNBc,
    USB,
    UsbJoin,
    aBNBcJoin,
    REALaBNBcJoin,
    ceBNBcJoin,
    Oracle,
    REALOracle,
    JUG,
    VOW,
    DOG,
    INTERACTION,
    REWARDS,
    ABACI,
    CLIP1,
    CLIP2,
    CLIP3,
    COLLATERAL_ABNBC,
    COLLATERAL_REAL_ABNBC,
    COLLATERAL_CE_ABNBC,
} = require('../../addresses-stage.json');
const {ethers} = require("hardhat");
const {BN} = require("@openzeppelin/test-helpers");

async function main() {
    console.log('Running deploy script');

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String(COLLATERAL_ABNBC);
    let collateral2 = ethers.utils.formatBytes32String(COLLATERAL_REAL_ABNBC);
    let collateral3 = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);

    this.Abaci = await ethers.getContractFactory("LinearDecrease");
    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Usb = await hre.ethers.getContractFactory("Usb");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.UsbJoin = await hre.ethers.getContractFactory("UsbJoin");
    this.Oracle = await hre.ethers.getContractFactory("Oracle");
    this.Interaction = await hre.ethers.getContractFactory("DAOInteraction");
    this.Jug = await hre.ethers.getContractFactory("Jug");
    this.Clip = await hre.ethers.getContractFactory("Clipper");
    this.Dog = await hre.ethers.getContractFactory("Dog");

    let abaci = await this.Abaci.attach(ABACI);

    console.log("Setting permissions");

    let oracle = this.Oracle.attach(Oracle);
    let oracle2 = this.Oracle.attach(REALOracle);
    await oracle.setPrice("400" + wad); // 2$, mat = 80%, 2$ * 80% = 1.6$ With Safety Margin
    await oracle2.setPrice("300" + wad); // 400$, mat = 80%, 400$ * 80% = 320$ With Safety Margin

    console.log("Vat rely...");

    let vat = this.Vat.attach(VAT);
    await vat.rely(aBNBcJoin);
    await vat.rely(REALaBNBcJoin);
    await vat.rely(ceBNBcJoin);
    await vat.rely(SPOT);
    await vat.rely(UsbJoin);
    await vat.rely(JUG);
    await vat.rely(DOG);

    await vat.rely(INTERACTION);

    console.log("Vat config...");
    await vat["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "500000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray);
    await vat["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray);
    await vat["file(bytes32,bytes32,uint256)"](collateral3, ethers.utils.formatBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral3, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray);

    console.log("Spot...");
    let spot = this.Spot.attach(SPOT);
    await spot["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), Oracle);
    await spot["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio

    await spot["file(bytes32,bytes32,address)"](collateral2, ethers.utils.formatBytes32String("pip"), REALOracle);
    await spot["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio

    await spot["file(bytes32,bytes32,address)"](collateral3, ethers.utils.formatBytes32String("pip"), Oracle);
    await spot["file(bytes32,bytes32,uint256)"](collateral3, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio

    await spot["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // It means pegged to 1$
    await spot.poke(collateral);
    await spot.poke(collateral2);
    await spot.poke(collateral3);

    console.log("Jug...");
    let BR = new BN("1000000003022266000000000000").toString(); //10% APY
    let jug = this.Jug.attach(JUG);
    await jug["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), BR); // 10% Yearly
    await jug["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);

    console.log("Usb...");
    let usb = this.Usb.attach(USB);
    await usb.rely(UsbJoin);

    // Initialize Liquidation Module
    console.log("Dog...");
    let dog = this.Dog.attach(DOG);
    await dog.rely(CLIP1);
    await dog.rely(CLIP2);
    await dog.rely(CLIP3);
    await dog["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);
    await dog["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Hole"), "500" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("hole"), "250" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("chop"), "1100000000000000000"); // 10%
    await dog["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("clip"), CLIP1);

    await dog["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("hole"), "250" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("chop"), "1100000000000000000"); // 10%
    await dog["file(bytes32,bytes32,address)"](collateral2, ethers.utils.formatBytes32String("clip"), CLIP2);

    await dog["file(bytes32,bytes32,uint256)"](collateral3, ethers.utils.formatBytes32String("hole"), "250" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateral3, ethers.utils.formatBytes32String("chop"), "1100000000000000000"); // 10%
    await dog["file(bytes32,bytes32,address)"](collateral3, ethers.utils.formatBytes32String("clip"), CLIP3);

    console.log("CLIP1");
    let clip1 = this.Clip.attach(CLIP1);
    await clip1.rely(DOG);
    await clip1["file(bytes32,uint256)"](ethers.utils.formatBytes32String("buf"), "1100000000000000000000000000"); // 10%
    await clip1["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tail"), "1800"); // 30mins reset time
    await clip1["file(bytes32,uint256)"](ethers.utils.formatBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
    await clip1["file(bytes32,uint256)"](ethers.utils.formatBytes32String("chip"), "10000000000000000"); // 1% from vow incentive
    await clip1["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
    await clip1["file(bytes32,uint256)"](ethers.utils.formatBytes32String("stopped"), "0");
    await clip1["file(bytes32,address)"](ethers.utils.formatBytes32String("spotter"), SPOT);
    await clip1["file(bytes32,address)"](ethers.utils.formatBytes32String("dog"), DOG);
    await clip1["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);
    await clip1["file(bytes32,address)"](ethers.utils.formatBytes32String("calc"), abaci.address);

    console.log("CLIP2");
    let clip2 = this.Clip.attach(CLIP2);
    await clip2.rely(DOG);
    await clip2["file(bytes32,uint256)"](ethers.utils.formatBytes32String("buf"), "1100000000000000000000000000"); // 10%
    await clip2["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tail"), "1800"); // 30mins reset time
    await clip2["file(bytes32,uint256)"](ethers.utils.formatBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
    await clip2["file(bytes32,uint256)"](ethers.utils.formatBytes32String("chip"), "10000000000000000"); // 1% from vow incentive
    await clip2["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
    await clip2["file(bytes32,uint256)"](ethers.utils.formatBytes32String("stopped"), "0");
    await clip2["file(bytes32,address)"](ethers.utils.formatBytes32String("spotter"), SPOT);
    await clip2["file(bytes32,address)"](ethers.utils.formatBytes32String("dog"), DOG);
    await clip2["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);
    await clip2["file(bytes32,address)"](ethers.utils.formatBytes32String("calc"), abaci.address);

    console.log("CLIP3");
    let clip3 = this.Clip.attach(CLIP3);
    await clip3.rely(DOG);
    await clip3["file(bytes32,uint256)"](ethers.utils.formatBytes32String("buf"), "1100000000000000000000000000"); // 10%
    await clip3["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tail"), "1800"); // 30mins reset time
    await clip3["file(bytes32,uint256)"](ethers.utils.formatBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
    await clip3["file(bytes32,uint256)"](ethers.utils.formatBytes32String("chip"), "10000000000000000"); // 1% from vow incentive
    await clip3["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
    await clip3["file(bytes32,uint256)"](ethers.utils.formatBytes32String("stopped"), "0");
    await clip3["file(bytes32,address)"](ethers.utils.formatBytes32String("spotter"), SPOT);
    await clip3["file(bytes32,address)"](ethers.utils.formatBytes32String("dog"), DOG);
    await clip3["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);
    await clip3["file(bytes32,address)"](ethers.utils.formatBytes32String("calc"), abaci.address);

    await abaci["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tau"), "3600"); // Price will reach 0 after this time


    console.log("Interaction...");
    let interaction = this.Interaction.attach(INTERACTION);

    console.log(collateral3);
    await interaction.setCollateralType(aBNBc, aBNBcJoin, collateral, CLIP1);
    await interaction.setCollateralType(REAL_ABNBC, REALaBNBcJoin, collateral2, CLIP2);
    await interaction.setCollateralType(ceBNBc, ceBNBcJoin, collateral3, CLIP3);
    await interaction.drip(aBNBc);
    await interaction.drip(REAL_ABNBC);
    await interaction.drip(ceBNBc);

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
