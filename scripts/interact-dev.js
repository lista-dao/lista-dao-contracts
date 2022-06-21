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
    INTERACTION, REWARDS, DOG, COLLATERAL_FAKE_ABNBC, FAKE_ABNBC_ILK,
    CLIP, COLLATERAL_CE_ABNBC, ceBNBc, ceBNBcJoin, AUCTION_PROXY
} = require('../addresses.json');
const {ether} = require("@openzeppelin/test-helpers");
const {ethers, upgrades} = require("hardhat");


let ME = "0x8E0eeC5bCf1Ee6AB986321349ff4D08019e29918";

let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

    let newCollateral = ethers.utils.formatBytes32String(COLLATERAL_FAKE_ABNBC);
    console.log("CeToken ilk: " + newCollateral);

    this.VAT = await hre.ethers.getContractFactory("Vat");
    this.SPOT = await hre.ethers.getContractFactory("Spotter");

    this.Interaction = await hre.ethers.getContractFactory("Interaction", {
        libraries: {
            AuctionProxy: AUCTION_PROXY
        }
    });

    let vat = this.VAT.attach(VAT);
    let spot = this.SPOT.attach(SPOT);
    this.HayFactory = await ethers.getContractFactory("Hay");
    let hay = this.HayFactory.attach(HAY);
    let abnbc = this.HayFactory.attach(aBNBc);

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [ME],
    });
    const signer = await ethers.getSigner(ME)

    let interaction = this.Interaction.attach(INTERACTION);


    // await abnbc.connect(signer).approve(interaction.address, ether("1000").toString());
    // await interaction.connect(signer).deposit(ME, aBNBc, ether("1").toString());
    await interaction.connect(signer).borrow(aBNBc, ether("1").toString());

    await hay.connect(signer).approve(interaction.address, ether("1000").toString());
    await interaction.connect(signer).payback(aBNBc, ether("1").toString());
    // await spot.connect(signer).poke(FAKE_ABNBC_ILK);

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [ME],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
