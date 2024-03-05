const hre = require("hardhat");

const { VAT,
    SPOT,
    aBNBc,
    HAY,
    HayJoin,
    aBNBcJoin,
    REALaBNBcJoin,
    REALOracle,
    JUG,
    Oracle,
    VOW,
    INTERACTION, REWARDS, DOG, DEPLOYER,
    CLIP, COLLATERAL_CE_ABNBC, ceBNBc, ceBNBcJoin, AUCTION_PROXY
} = require('../addresses.json');
const {ether} = require("@openzeppelin/test-helpers");
const {ethers, upgrades} = require("hardhat");


let MIKHAIL = "0x57f9672ba603251c9c03b36cabdbbca7ca8cfcf4";
let TESTER = "0xb23b8d18EE1222Dc9Fc83F538419417bF0442572";

let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

    let newCollateral = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);
    console.log("CeToken ilk: " + newCollateral);

    this.VAT = await hre.ethers.getContractFactory("Vat");

    this.Interaction = await hre.ethers.getContractFactory("Interaction", {
        libraries: {
            AuctionProxy: AUCTION_PROXY
        }
    });
    //
    // const interactionNew = await upgrades.deployProxy(this.Interaction, [
    //     VAT,
    //     SPOT,
    //     HAY,
    //     HayJoin,
    //     JUG,
    //     DOG,
    //     REWARDS,
    // ], {
    //     initializer: "initialize"
    // });
    //
    let vat = this.VAT.attach(VAT);
    this.HayFactory = await ethers.getContractFactory("Hay");
    this.Dog = await ethers.getContractFactory("Dog");
    let hay = this.HayFactory.attach(HAY);
    let dog = this.Dog.attach(DOG);
    //
    // await hre.network.provider.request({
    //     method: "hardhat_impersonateAccount",
    //     params: ["0x73CF7cC1778a60d43Ca2833F419B77a76177156A"],
    // });
    // const signerDeployer = await ethers.getSigner("0x73CF7cC1778a60d43Ca2833F419B77a76177156A")
    //
    // await vat.connect(signerDeployer)["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("dust"), "1" + ray);
    // // await vat.connect(signerDeployer).rely(interactionNew.address);
    // // await vat.connect(signerDeployer).behalf("0x37a7d129df800a4c75d13b2d94e1afc024a54fed", interactionNew.address);
    // //
    // await hre.network.provider.request({
    //     method: "hardhat_stopImpersonatingAccount",
    //     params: ["0x73CF7cC1778a60d43Ca2833F419B77a76177156A"],
    // });

    // await interactionNew.enableCollateralType(ceBNBc, ceBNBcJoin, newCollateral, CLIP);

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [TESTER],
    });
    const signer = await ethers.getSigner(TESTER)

    let interaction = this.Interaction.attach(INTERACTION);

    // let hayBalance = await vat.hay(MIKHAIL);
    // console.log(hayBalance);

    // let amount = "700000000000000000000";
    // await hay.connect(signer).approve(interaction.address, amount);
    // await interactionNew.connect(signer).payback("0x37a7d129df800a4c75d13b2d94e1afc024a54fed",
    //     "0x24308Ca3B62129D51ecfA99410d6B59e0E6c7bfD",
    //     "5000000000000000000")
    let liq = "0x73CF7cC1778a60d43Ca2833F419B77a76177156A";
    // await dog.connect(signer)["file(bytes32,bytes32,uint256)"](newCollateral, ethers.utils.formatBytes32String("hole"), "500" + rad);
    await interaction.connect(signer).startAuction(ceBNBc, liq, TESTER);

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [TESTER],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
