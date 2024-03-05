const {
    ceBNBc, DEPLOYER, COLLATERAL_CE_ABNBC, aBNBc,
    Oracle, HELIO_PROVIDER, COLLATERAL_FAKE_ABNBC,
    ABACI, SPOT, DOG, VOW, CLIP,
} = require('../../addresses.json');
const {ethers, upgrades} = require("hardhat");

let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {
    console.log('Running deploy script');

    let collateralFAKE = ethers.encodeBytes32String(COLLATERAL_FAKE_ABNBC);
    let collateralCE = ethers.encodeBytes32String(COLLATERAL_CE_ABNBC);
    console.log("IlkFake: " + collateralFAKE);
    console.log("IlkCE: " + collateralCE);

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
    await vat.waitForDeployment();
    console.log("Vat deployed to:", vat.target);

    const spot = await this.Spot.deploy(vat.target);
    await spot.waitForDeployment();
    console.log("Spot deployed to:", spot.target);

    const hay = await this.Hay.deploy(97, "HAY");
    await hay.waitForDeployment();
    console.log("Hay deployed to:", hay.target);

    const hayJoin = await this.HayJoin.deploy(vat.target, hay.target);
    await hayJoin.waitForDeployment();
    console.log("hayJoin deployed to:", hayJoin.target);

    const bnbJoin = await this.GemJoin.deploy(vat.target, collateralCE, ceBNBc);
    await bnbJoin.waitForDeployment();
    console.log("bnbJoin deployed to:", bnbJoin.target);

    const fakeJoin = await this.GemJoin.deploy(vat.target, collateralFAKE, aBNBc);
    await fakeJoin.waitForDeployment();
    console.log("FakeJoin deployed to:", fakeJoin.target);

    const jug = await this.Jug.deploy(vat.target);
    await jug.waitForDeployment();
    console.log("Jug deployed to:", jug.target);

    const vow = await this.Vow.deploy(vat.target, ethers.ZeroAddress, ethers.ZeroAddress, DEPLOYER);
    await vow.waitForDeployment();
    console.log("Vow deployed to:", vow.target);

    const dog = await this.Dog.deploy(vat.target);
    await dog.waitForDeployment();
    console.log("Dog deployed to:", dog.target);

    const clipCE = await this.Clip.deploy(vat.target, spot.target, dog.target, collateralCE);
    await clipCE.waitForDeployment();
    console.log("ClipCE deployed to:", clipCE.target);

    const clipFAKE = await this.Clip.deploy(vat.target, spot.target, dog.target, collateralFAKE);
    await clipFAKE.waitForDeployment();
    console.log("ClipFAKE deployed to:", clipFAKE.target);

    console.log("Core contracts auth");

    await vat.rely(bnbJoin.target);
    await vat.rely(fakeJoin.target);
    await vat.rely(spot.target);
    await vat.rely(hayJoin.target);
    await vat.rely(jug.target);
    await vat.rely(dog.target);

     // REWARDS
    console.log("Deploying rewards");

    const rewards = await upgrades.deployProxy(this.HelioRewards, [
        vat.target,
        100000000n // pool limit
    ]);
    await rewards.waitForDeployment();
    console.log("Rewards deployed to:", rewards.target);

    // No HELIO token & Oracle at this moment
    // const helioOracle = await upgrades.deployProxy(this.HelioOracle, [
    //     "100000000000000000" // 0.1
    // ]);
    // await helioOracle.waitForDeployment();
    // console.log("helioOracle deployed to:", helioOracle.target);

    // const helioToken = await this.HelioToken.deploy(100000000n, rewards.target);
    // await helioToken.waitForDeployment();
    // console.log("helioToken deployed to:", helioToken.target);
    //
    // await rewards.setHelioToken(helioToken.target);
    // await rewards.setOracle(helioOracle.target);
    // await rewards.initPool(ceBNBc, collateral, "1000000001847694957439350500"); //6%

    // INTERACTION
    const auctionProxy = await this.AuctionProxy.deploy();
    await auctionProxy.waitForDeployment();
    console.log("AuctionProxy lib deployed to: ", auctionProxy.target);

    this.Interaction = await hre.ethers.getContractFactory("Interaction", {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: auctionProxy.target
        }
    });
    const interaction = await upgrades.deployProxy(this.Interaction, [
        vat.target,
        spot.target,
        hay.target,
        hayJoin.target,
        jug.target,
        dog.target,
        rewards.target
    ], {
        unsafeAllowLinkedLibraries: true,
    });
    await interaction.waitForDeployment();
    console.log("interaction deployed to:", interaction.target);

    await vat.rely(interaction.target);
    await rewards.rely(interaction.target);
    await bnbJoin.rely(interaction.target);
    await fakeJoin.rely(interaction.target);
    await hayJoin.rely(interaction.target);
    await dog.rely(interaction.target);
    await jug.rely(interaction.target);
    await vow.rely(dog.target);
    await interaction.setHelioProvider(ceBNBc, HELIO_PROVIDER);

    console.log("Vat config...");
    await vat["file(bytes32,uint256)"](ethers.encodeBytes32String("Line"), "500000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateralCE, ethers.encodeBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateralCE, ethers.encodeBytes32String("dust"), "1" + ray);
    await vat["file(bytes32,bytes32,uint256)"](collateralFAKE, ethers.encodeBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](collateralFAKE, ethers.encodeBytes32String("dust"), "1" + ray);

    console.log("Spot...");
    await spot["file(bytes32,bytes32,address)"](collateralCE, ethers.encodeBytes32String("pip"), Oracle);
    await spot["file(bytes32,bytes32,uint256)"](collateralCE, ethers.encodeBytes32String("mat"), "1333333333333333333333333333"); // Liquidation Ratio
    await spot["file(bytes32,bytes32,address)"](collateralFAKE, ethers.encodeBytes32String("pip"), Oracle);
    await spot["file(bytes32,bytes32,uint256)"](collateralFAKE, ethers.encodeBytes32String("mat"), "1333333333333333333333333333"); // Liquidation Ratio

    await spot["file(bytes32,uint256)"](ethers.encodeBytes32String("par"), "1" + ray); // It means pegged to 1$
    await spot.poke(collateralCE);
    await spot.poke(collateralFAKE);

    console.log("Jug...");
    let BR = 1000000003022266000000000000n; //10% APY
    await jug["file(bytes32,uint256)"](ethers.encodeBytes32String("base"), BR); // 10% Yearly
    await jug["file(bytes32,address)"](ethers.encodeBytes32String("vow"), vow.target);

    console.log("Hay...");
    await hay.rely(hayJoin.target);

    // Initialize Liquidation Module
    console.log("Dog...");
    await dog.rely(clipCE.target);
    await dog.rely(clipFAKE.target);
    await dog["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.target);
    await dog["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Hole"), "500" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateralCE, ethers.encodeBytes32String("hole"), "250" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateralCE, ethers.encodeBytes32String("chop"), "1100000000000000000"); // 10%
    await dog["file(bytes32,bytes32,address)"](collateralCE, ethers.encodeBytes32String("clip"), clipCE.target);
    await dog["file(bytes32,bytes32,uint256)"](collateralFAKE, ethers.encodeBytes32String("hole"), "250" + rad);
    await dog["file(bytes32,bytes32,uint256)"](collateralFAKE, ethers.encodeBytes32String("chop"), "1100000000000000000"); // 10%
    await dog["file(bytes32,bytes32,address)"](collateralFAKE, ethers.encodeBytes32String("clip"), clipFAKE.target);


    console.log("CLIP");
    // let clip = this.Clip.attach(CLIP);
    await clipCE.rely(DOG);

    await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("buf"), "1100000000000000000000000000"); // 10%
    await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("tail"), "1800"); // 30mins reset time
    await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
    await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("chip"), "10000000000000000"); // 1% from vow incentive
    await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
    await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("stopped"), "0");
    await clipCE["file(bytes32,address)"](ethers.encodeBytes32String("spotter"), SPOT);
    await clipCE["file(bytes32,address)"](ethers.encodeBytes32String("dog"), DOG);
    await clipCE["file(bytes32,address)"](ethers.encodeBytes32String("vow"), VOW);
    await clipCE["file(bytes32,address)"](ethers.encodeBytes32String("calc"), ABACI);

    await clipFAKE["file(bytes32,uint256)"](ethers.encodeBytes32String("buf"), "1100000000000000000000000000"); // 10%
    await clipFAKE["file(bytes32,uint256)"](ethers.encodeBytes32String("tail"), "1800"); // 30mins reset time
    await clipFAKE["file(bytes32,uint256)"](ethers.encodeBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
    await clipFAKE["file(bytes32,uint256)"](ethers.encodeBytes32String("chip"), "10000000000000000"); // 1% from vow incentive
    await clipFAKE["file(bytes32,uint256)"](ethers.encodeBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
    await clipFAKE["file(bytes32,uint256)"](ethers.encodeBytes32String("stopped"), "0");
    await clipFAKE["file(bytes32,address)"](ethers.encodeBytes32String("spotter"), SPOT);
    await clipFAKE["file(bytes32,address)"](ethers.encodeBytes32String("dog"), DOG);
    await clipFAKE["file(bytes32,address)"](ethers.encodeBytes32String("vow"), VOW);
    await clipFAKE["file(bytes32,address)"](ethers.encodeBytes32String("calc"), ABACI);

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
