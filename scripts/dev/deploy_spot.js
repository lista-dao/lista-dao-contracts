const hre = require("hardhat");

const {
    REAL_ABNBC, ceBNBc, DEPLOYER, Oracle, SPOT, VAT, FAKE_ABNBC_ILK, AUCTION_PROXY, INTERACTION
} = require('../../addresses.json');
const {ethers} = require("hardhat");


async function main() {
    console.log('Running deploy script');

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000", // 45 Decimals
        ONE = 10 ** 27;

    let collateral = FAKE_ABNBC_ILK;

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Hay = await hre.ethers.getContractFactory("Hay");
    this.ABNBC = await hre.ethers.getContractFactory("aBNBc");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.HayJoin = await hre.ethers.getContractFactory("HayJoin");
    this.Oracle = await hre.ethers.getContractFactory("Oracle"); // Mock Oracle
    this.Jug = await hre.ethers.getContractFactory("Jug");
    this.Vow = await hre.ethers.getContractFactory("Vow");
    this.Jar = await hre.ethers.getContractFactory("Jar");
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Clip = await hre.ethers.getContractFactory("Clipper");

    const spot = await this.Spot.deploy(VAT);
    await spot.deployed();
    console.log("spot deployed to:", spot.address);

    await spot["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), Oracle);
    await spot["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio
    await spot.poke(collateral);

    this.Interaction = await hre.ethers.getContractFactory("Interaction", {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: AUCTION_PROXY
        },
    });
    let interaction = this.Interaction.attach(INTERACTION);
    await interaction.setSpot(spot.address);

    console.log('Validating code');
    await hre.run("verify:verify", {
        address: spot.address,
        constructorArguments: [
            VAT
        ]
    });

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
