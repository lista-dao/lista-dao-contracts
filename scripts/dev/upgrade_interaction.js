const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

let { interaction, auctionProxy } = require('../../addresses/bsc_testnet.json');
const oldContractName = 'InteractionV3'
const contractName = 'Interaction'
const resetAuctionProxy = false

async function main() {
    console.log('Running deploy script');
    if (resetAuctionProxy) {
        const AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");
        const auctionProxyContract = await AuctionProxy.deploy();
        await auctionProxyContract.waitForDeployment();
        console.log("AuctionProxy deployed to: ", auctionProxyContract.address);
        auctionProxy = auctionProxyContract.address;
    }

    const Interaction = await hre.ethers.getContractFactory(contractName, {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: auctionProxy
        },
    });

    console.log('Validate if its upgradable...')
    const OldInteraction = await ethers.getContractFactory(oldContractName, {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: auctionProxy,
        },
    });
    await upgrades.forceImport(interaction, OldInteraction, { kind: 'transparent' });
    await upgrades.validateUpgrade(interaction, Interaction, { unsafeAllow: ['external-library-linking'] })
    console.log('Updatability is validated successfully.')

    //
    // console.log('Force importing proxy');
    // await upgrades.forceImport(interaction, Interaction);

    // console.log("Preparing upgrade...");
    // const interactionV2 = await upgrades.prepareUpgrade(interaction, Interaction, {
    //     kind: "uups",
    //     unsafeAllowLinkedLibraries: true,
    // });
    // console.log("interactionV2 ", interactionV2);
    const upgraded = await upgrades.upgradeProxy(interaction, Interaction, {
        kind: "transparent",
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
