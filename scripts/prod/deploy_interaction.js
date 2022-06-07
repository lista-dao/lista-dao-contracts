const hre = require("hardhat");
const {ethers, upgrades} = require("hardhat");
require("@nomiclabs/hardhat-etherscan");

const {
    VAT,
    SPOT,
    HAY,
    HayJoin,
    JUG,
    REWARDS,
    DOG, DEPLOYER,
} = require('../../addresses-stage2.json');

async function main() {
    console.log('Running deploy script');

    this.AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");
    const auctionProxy = await this.AuctionProxy.deploy();
    await auctionProxy.deployed();
    console.log("AuctionProxy lib deployed to: ", auctionProxy.address);

    this.Interaction = await hre.ethers.getContractFactory("Interaction", {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: auctionProxy.address
        },
    });
    const interaction = await upgrades.deployProxy(this.Interaction, [
        VAT,
        SPOT,
        HAY,
        HayJoin,
        JUG,
        DOG,
        REWARDS
    ], {
        initializer: "initialize",
        unsafeAllowLinkedLibraries: true,
    });
    await interaction.deployed();
    console.log("interaction deployed to:", interaction.address);

    console.log('Validating code');
    let interactionImplAddress = await upgrades.erc1967.getImplementationAddress(interaction.address);
    console.log("Interaction implementation: ", interactionImplAddress);

    await hre.run("verify:verify", {
        address: interactionImplAddress,
    });

    await hre.run("verify:verify", {
        address: interaction.address,
    });

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
