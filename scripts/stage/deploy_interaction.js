const hre = require("hardhat");
const {ethers, upgrades} = require("hardhat");
require("@nomiclabs/hardhat-etherscan");

const {
    VAT,
    SPOT,
    USB,
    UsbJoin,
    JUG,
    REWARDS,
    DOG,
} = require('../../addresses-stage.json');

async function main() {
    console.log('Running deploy script');

    let Interaction = await hre.ethers.getContractFactory("DAOInteraction");
    this.Rewards = await hre.ethers.getContractFactory("HelioRewards");
    let rewards = this.Rewards.attach(REWARDS);
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
    await rewards.rely(interaction.address);

    console.log('Validating code');
    let interactionImplAddress = await upgrades.erc1967.getImplementationAddress(interaction.address);
    console.log("Interaction implementation: ", interactionImplAddress);

    await hre.run("verify:verify", {
        address: interactionImplAddress,
    });

    await hre.run("verify:verify", {
        address: interaction.address,
        constructorArguments: [
            VAT,
            SPOT,
            USB,
            UsbJoin,
            JUG,
            DOG,
            REWARDS
        ],
    });

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
