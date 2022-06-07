const hre = require("hardhat");

const {
    ceBNBc, DEPLOYER, COLLATERAL_CE_ABNBC,
    Oracle,
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

    const vat = await upgrades.deployProxy(this.Vat, []);
    await vat.deployed();
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

    console.log("Core contracts auth");

    await vat.rely(bnbJoin.address);
    await vat.rely(spot.address);
    await vat.rely(hayJoin.address);
    await vat.rely(jug.address);
    await vat.rely(dog.address);

     // REWARDS
    console.log("Deploying rewards");

    const rewards = await upgrades.deployProxy(this.HelioRewards, [
        vat.address,
        ether("100000000").toString()// pool limit
    ]);
    await rewards.deployed();
    console.log("Rewards deployed to:", rewards.address);

    const helioOracle = await upgrades.deployProxy(this.HelioOracle, [
        "100000000000000000" // 0.1
    ]);
    await helioOracle.deployed();
    console.log("helioOracle deployed to:", helioOracle.address);

    const helioToken = await this.HelioToken.deploy(ether("100000000").toString(), rewards.address);
    await helioToken.deployed();
    console.log("helioToken deployed to:", helioToken.address);

    await rewards.setHelioToken(helioToken.address);
    await rewards.setOracle(helioOracle.address);
    // await rewards.initPool(ceBNBc, collateral, "1000000001847694957439350500"); //6%

    // INTERACTION
    const auctionProxy = await this.AuctionProxy.deploy();
    await auctionProxy.deployed();
    console.log("AuctionProxy lib deployed to: ", auctionProxy.address);

    this.Interaction = await hre.ethers.getContractFactory("Interaction", {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: auctionProxy.address
        }
    });
    const interaction = await upgrades.deployProxy(this.Interaction, [
        vat.address,
        spot.address,
        hay.address,
        hayJoin.address,
        jug.address,
        dog.address,
        rewards.address
    ], {
        initializer: "initialize",
        unsafeAllowLinkedLibraries: true,
    });
    await interaction.deployed();
    console.log("interaction deployed to:", interaction.address);

    await vat.rely(interaction.address);
    await rewards.rely(interaction.address);
    await bnbJoin.rely(interaction.address);
    await hayJoin.rely(interaction.address);
    await dog.rely(interaction.address);
    await jug.rely(interaction.address);

    console.log("Vat config...");
    await vat["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "500000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray);

    console.log("Spot...");
    await spot["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), Oracle);
    await spot["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("mat"), "1333333333333333333333333333"); // Liquidation Ratio

    await spot["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // It means pegged to 1$
    await spot.poke(collateral);

    console.log("Jug...");
    let BR = new BN("1000000003022266000000000000").toString(); //10% APY
    await jug["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), BR); // 10% Yearly
    await jug["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);

    console.log("Hay...");
    await hay.rely(hayJoin.address);

    // Initialize Liquidation Module
    console.log("Dog...");
    await dog.rely(clip.address);
    await dog["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);
    await dog["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Hole"), "500" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("hole"), "250" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("chop"), "1100000000000000000"); // 10%
    await dog["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("clip"), clip.address);

    console.log("CLIP");
    // let clip = this.Clip.attach(CLIP);
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

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });