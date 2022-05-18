const hre = require("hardhat");

const { VAT,
    SPOT,
    aBNBc,
    USB,
    UsbJoin,
    aBNBcJoin,
    REALaBNBcJoin,
    REALOracle,
    JUG,
    Oracle,
    VOW,
    INTERACTION, REAL_ABNBC, REWARDS, DOG,
    CLIP1, CLIP3, COLLATERAL_CE_ABNBC, ceBNBc, ceBNBcJoin
} = require('../addresses-stage.json');
const {ether} = require("@openzeppelin/test-helpers");
const {ethers, upgrades} = require("hardhat");

async function main() {

    let newCollateral = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);
    console.log("CeToken ilk: " + newCollateral);

    this.Provider = await hre.ethers.getContractFactory("HelioProvider");
    let provider = this.Provider.attach("0xa08C7C4FBF8195923bA29C368621Cf45EAAF7A2d");
    // this.VAT = await hre.ethers.getContractFactory("Vat");
    //
    // this.Interaction = await hre.ethers.getContractFactory("Interaction");
    //
    // const interactionNew = await upgrades.deployProxy(this.Interaction, [
    //     VAT,
    //     SPOT,
    //     USB,
    //     UsbJoin,
    //     JUG,
    //     DOG,
    //     REWARDS,
    // ], {
    //     initializer: "initialize"
    // });
    //
    // let vat = this.VAT.attach(VAT);
    // this.UsbFactory = await ethers.getContractFactory("Usb");
    // let usb = this.UsbFactory.attach(USB);

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0x73CF7cC1778a60d43Ca2833F419B77a76177156A"],
    });
    const signerDeployer = await ethers.getSigner("0x73CF7cC1778a60d43Ca2833F419B77a76177156A")

    // await vat.connect(signerDeployer).rely(interactionNew.address);
    // await vat.connect(signerDeployer).behalf("0x37a7d129df800a4c75d13b2d94e1afc024a54fed", interactionNew.address);

    provider2 = ethers.provider;
    balance = await provider2.getBalance(signerDeployer.address);
    console.log(balance.toString());
    await provider.connect(signerDeployer).provide({value: ether("1.1").toString()});
    balance = await provider2.getBalance(signerDeployer.address);
    console.log(balance.toString());

    // await provider.connect(signerDeployer).release(ether("1010000000000000000").toString());

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: ["0x73CF7cC1778a60d43Ca2833F419B77a76177156A"],
    });

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
