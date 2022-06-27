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
    AUCTION_PROXY
} = require('../../addresses.json');

async function main() {
    console.log('Running deploy script');

    const Interaction = await hre.ethers.getContractFactory("Interaction", {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: AUCTION_PROXY
        },
    });
    //
    // console.log('Force importing proxy');
    // await upgrades.forceImport(INTERACTION, Interaction);

    // console.log("Preparing upgrade...");
    // const interactionV2 = await upgrades.prepareUpgrade(INTERACTION, Interaction, {
    //     kind: "uups",
    //     unsafeAllowLinkedLibraries: true,
    // });
    // console.log("interactionV2 ", interactionV2);
    const upgraded = await upgrades.upgradeProxy(INTERACTION, Interaction, {
        kind: "uups",
        unsafeAllowLinkedLibraries: true,
    });
    console.log("interactionV2 upgraded with ", upgraded.address);

    console.log('Validating code');

    let interactionImplAddress = await upgrades.erc1967.getImplementationAddress(upgraded.address);
    console.log("Interaction implementation: ", interactionImplAddress);

    await hre.run("verify:verify", {
        address: interactionImplAddress,
    });

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
