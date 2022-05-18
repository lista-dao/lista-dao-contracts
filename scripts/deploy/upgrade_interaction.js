const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
require("@nomiclabs/hardhat-etherscan");

const { VAT,
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
} = require('../../addresses.json');

async function main() {
    console.log('Running deploy script');

    const Interaction = await hre.ethers.getContractFactory("DAOInteraction");
    //
    // console.log('Force importing proxy');
    // await upgrades.forceImport(INTERACTION, Interaction);

    console.log("Preparing upgrade...");
    const interactionV2 = await upgrades.prepareUpgrade(INTERACTION, Interaction, {kind: "uups"});
    console.log("interactionV2 ", interactionV2);
    const upgraded = await upgrades.upgradeProxy(INTERACTION, Interaction, {kind: "uups"});
    console.log("interactionV2 upgraded with ", upgraded.address);

    console.log('Validating code');
    await hre.run("verify:verify", {
        address: interactionV2,
    });
    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
