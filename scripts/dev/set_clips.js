const {
    REAL_ABNBC, ceBNBc, DEPLOYER, Oracle, SPOT, VAT,
    FAKE_ABNBC_ILK, AUCTION_PROXY, INTERACTION, DOG, VOW, ABACI,
    CLIP1, CLIP3,
} = require('../../addresses.json');
const {ethers} = require("hardhat");


async function main() {
    console.log('Running deploy script');

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000", // 45 Decimals
        ONE = 10 ** 27;

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

    const clipCE = await this.Clip.attach(CLIP3);
    console.log("CLIP CE");
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

    const clipFAKE = await this.Clip.attach(CLIP1);
    console.log("CLIP FAKE");
    await clipFAKE.rely(DOG);
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
