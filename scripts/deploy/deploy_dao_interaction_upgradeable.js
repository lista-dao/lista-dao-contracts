const hre = require("hardhat");
const {ethers, upgrades} = require("hardhat");
require("@nomiclabs/hardhat-etherscan");

const {
    VAT,
    SPOT,
    aBNBc,
    USB,
    UsbJoin,
    aBNBcJoin,
    Oracle,
    JUG,
    REAL_ABNBC,
    REALaBNBcJoin,
    INTERACTION,
    REWARDS,
    DOG,
    CLIP1,
    CLIP2,
} = require('../../addresses.json');

async function main() {
    console.log('Running deploy script');

    Interaction = await hre.ethers.getContractFactory("DAOInteraction");
    // const interaction = Interaction.attach(INTERACTION);
    const interaction = await upgrades.deployProxy(Interaction, [
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

    // // const interaction = await this.Interaction.deploy(
    // //     VAT,
    // //     SPOT,
    // //     USB,
    // //     UsbJoin,
    // //     JUG
    // // );
    // await interaction.deployed();
    console.log("interaction deployed to:", interaction.address);
    //
    this.Vat = await hre.ethers.getContractFactory("Vat");
    console.log("Vat...");
    //
    let vat = this.Vat.attach(VAT);
    await vat.rely(interaction.address);

    console.log('Adding collateral types');
    let collateral = ethers.utils.formatBytes32String("aBNBc");
    let collateral2 = ethers.utils.formatBytes32String("aBNBc2");

    // await interaction.setCollateralType(aBNBc, aBNBcJoin, collateral, CLIP1);
    // await interaction.setCollateralType(REAL_ABNBC, REALaBNBcJoin, collateral2, CLIP2);
    // await interaction.enableCollateralType(aBNBc, aBNBcJoin, collateral, CLIP1);
    // await interaction.enableCollateralType(REAL_ABNBC, REALaBNBcJoin, collateral2, CLIP2);
    // await interaction.drip(aBNBc);
    // await interaction.drip(REAL_ABNBC);

    console.log('Validating code');
    let interactionImplAddress = await upgrades.erc1967.getImplementationAddress(interaction.address);
    console.log("Interaction implementation: ", interactionImplAddress);

    await hre.run("verify:verify", {
        address: interactionImplAddress,
    });

    // await hre.run("verify:verify", {
    //     address: interaction.address,
    //     constructorArguments: [
    //         VAT,
    //         SPOT,
    //         USB,
    //         UsbJoin,
    //         JUG,
    //     ],
    // });

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
