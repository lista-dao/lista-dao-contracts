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

    this.VAT = await hre.ethers.getContractFactory("Vat");

    this.Interaction = await hre.ethers.getContractFactory("DAOInteraction");

    const interactionNew = await upgrades.deployProxy(this.Interaction, [
        VAT,
        SPOT,
        USB,
        UsbJoin,
        JUG,
        DOG,
        REWARDS,
    ], {
        initializer: "initialize"
    });

    let vat = this.VAT.attach(VAT);
    this.UsbFactory = await ethers.getContractFactory("Usb");
    let usb = this.UsbFactory.attach(USB);

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0x73CF7cC1778a60d43Ca2833F419B77a76177156A"],
    });
    const signerDeployer = await ethers.getSigner("0x73CF7cC1778a60d43Ca2833F419B77a76177156A")

    await vat.connect(signerDeployer).rely(interactionNew.address);
    await vat.connect(signerDeployer).behalf("0x37a7d129df800a4c75d13b2d94e1afc024a54fed", interactionNew.address);

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: ["0x73CF7cC1778a60d43Ca2833F419B77a76177156A"],
    });

    await interactionNew.enableCollateralType(ceBNBc, ceBNBcJoin, newCollateral, CLIP3);

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0x37a7d129df800a4c75d13b2d94e1afc024a54fed"],
    });
    const signer = await ethers.getSigner("0x37a7d129df800a4c75d13b2d94e1afc024a54fed")

    let interaction = this.Interaction.attach(INTERACTION);

    let usbBalance = await vat.usb("0x37a7d129df800a4c75d13b2d94e1afc024a54fed");
    console.log(usbBalance);

    await usb.connect(signer).approve(interactionNew.address, "5000000000000000000");
    await interactionNew.connect(signer).payback("0x37a7d129df800a4c75d13b2d94e1afc024a54fed",
        "0x24308Ca3B62129D51ecfA99410d6B59e0E6c7bfD",
        "5000000000000000000")
    // await interaction.connect(signer).payback("0x37a7d129df800a4c75d13b2d94e1afc024a54fed",
    //     "0x24308Ca3B62129D51ecfA99410d6B59e0E6c7bfD",
    //     "5000000000000000000")

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: ["0x37a7d129df800a4c75d13b2d94e1afc024a54fed"],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
