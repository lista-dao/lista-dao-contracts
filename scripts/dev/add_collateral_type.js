const hre = require("hardhat");

const { VAT,
    SPOT,
    aBNBc,
    USB,
    UsbJoin,
    aBNBcJoin,
    Oracle,
    JUG, VOW, ABACI,
    DOG, CLIP1,
    REAL_ABNBC, ceBNBc,COLLATERAL_FAKE_ABNBC,
    REALaBNBcJoin, COLLATERAL_CE_ABNBC,
    INTERACTION, AUCTION_PROXY,
} = require('../../addresses.json');
const {ethers} = require("hardhat");

let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {
    console.log('Running deploy script');

    let token = ceBNBc;

    let newCollateral = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);
    console.log("CeToken ilk: " + newCollateral);

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Clip = await hre.ethers.getContractFactory("Clipper");
    this.Interaction = await hre.ethers.getContractFactory("Interaction", {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: AUCTION_PROXY
        },
    });
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Jug = await hre.ethers.getContractFactory("Jug");
    this.Abaci = await ethers.getContractFactory("LinearDecrease");

    const clip = await this.Clip.deploy(VAT, SPOT, DOG, newCollateral);
    // const clip = await this.Clip.attach(CLIP1);
    await clip.deployed();
    console.log("Clip deployed to:", clip.address);

    const tokenJoin = await this.GemJoin.deploy(VAT, newCollateral, token);
    // const tokenJoin = await this.GemJoin.attach(aBNBcJoin);
    await tokenJoin.deployed();
    console.log("tokenJoin deployed to:", tokenJoin.address);
    await tokenJoin.rely(INTERACTION);

    let interaction = this.Interaction.attach(INTERACTION);
    let jug = this.Jug.attach(JUG);
    await jug.rely(INTERACTION);
    let spot = this.Spot.attach(SPOT);
    await spot.rely(INTERACTION);

    await interaction.setCollateralType(token, tokenJoin.address, newCollateral, clip.address, "1333333333333333333333333333");

    let vat = this.Vat.attach(VAT);

    await vat.rely(tokenJoin.address);
    await vat["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray);

    await spot["file(bytes32,bytes32,address)"](newCollateral, ethers.utils.formatBytes32String("pip"), Oracle);
    // await spot["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("mat"), "1333333333333333333333333333"); // Liquidation Ratio
    // await spot.poke(newCollateral);

    console.log("Dog...");
    let dog = this.Dog.attach(DOG);
    await dog.rely(clip.address);
    await dog["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("hole"), "250" + rad);
    await dog["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("chop"), "1100000000000000000"); // 10%
    await dog["file(bytes32,bytes32,address)"](newCollateral, ethers.utils.formatBytes32String("clip"), clip.address);

    console.log("clip");
    await clip.rely(DOG);
    await clip["file(bytes32,uint256)"](ethers.utils.formatBytes32String("buf"), "1100000000000000000000000000"); // 10%
    await clip["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tail"), "1800"); // 30mins reset time
    await clip["file(bytes32,uint256)"](ethers.utils.formatBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
    await clip["file(bytes32,uint256)"](ethers.utils.formatBytes32String("chip"), "10000000000000000"); // 1% from vow incentive
    await clip["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
    await clip["file(bytes32,uint256)"](ethers.utils.formatBytes32String("stopped"), "0");
    await clip["file(bytes32,address)"](ethers.utils.formatBytes32String("spotter"), SPOT);
    await clip["file(bytes32,address)"](ethers.utils.formatBytes32String("dog"), DOG);
    await clip["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);
    await clip["file(bytes32,address)"](ethers.utils.formatBytes32String("calc"), ABACI);

    await spot.poke(newCollateral);
    await interaction.drip(token);

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
