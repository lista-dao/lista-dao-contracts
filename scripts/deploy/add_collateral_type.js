const hre = require("hardhat");

const { VAT,
    SPOT,
    aBNBc,
    USB,
    UsbJoin,
    aBNBcJoin,
    Oracle,
    JUG, VOW, ABACI,
    DOG,
    REAL_ABNBC, ceBNBc,
    REALaBNBcJoin, COLLATERAL_CE_ABNBC,
    INTERACTION} = require('../../addresses.json');
const {ethers} = require("hardhat");

let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {
    console.log('Running deploy script');

    // let newCollateral = ethers.utils.formatBytes32String("ceToken");
    let newCollateral = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);
    console.log("CeToken ilk: " + newCollateral);

    // let tokenAddress = "0x51b9eFaB9C8D1ba25C76d3636b3E5784abD65dfC";
    // let tokenAddress = "0xCa33FBAb46a05D7f8e3151975543a3a1f7463F63";
    // let tokenAddress = "0x90c15Cd33f7B3b7dadCa7653419b493ABfC7B850";

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Clip = await hre.ethers.getContractFactory("Clipper");
    this.Interaction = await hre.ethers.getContractFactory("DAOInteraction");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Abaci = await ethers.getContractFactory("LinearDecrease");

    const clip = await this.Clip.deploy(VAT, SPOT, DOG, newCollateral);
    await clip.deployed();
    console.log("Clip deployed to:", clip.address);

    const tokenJoin = await this.GemJoin.deploy(VAT, newCollateral, ceBNBc);
    await tokenJoin.deployed();
    console.log("tokenJoin deployed to:", tokenJoin.address);

    // let tokenJoin = "0x5566bCc1e8CaCE6A8B924644C0CFFF5715F72ddb";
    // let clip = "0xca75156174114eAd8bd9dF1F50E894334041029b";

    let interaction = this.Interaction.attach(INTERACTION);

    // await interaction.setCollateralType(tokenAddress, tokenJoin, newCollateral, clip);

    // await interaction.setCollateralType(tokenAddress, tokenJoin.address, newCollateral, clip.address);
    await interaction.enableCollateralType(ceBNBc, tokenJoin.address, newCollateral, clip.address);

    let vat = this.Vat.attach(VAT);

    await vat.rely(tokenJoin.address);
    await vat["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("line"), "50000000" + rad);
    await vat["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray);

    let spot = this.Spot.attach(SPOT);
    await spot["file(bytes32,bytes32,address)"](newCollateral, ethers.utils.formatBytes32String("pip"), Oracle);
    await spot["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio
    await spot.poke(newCollateral);

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

    await interaction.drip(ceBNBc);

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
