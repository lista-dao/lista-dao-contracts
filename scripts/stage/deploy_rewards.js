const hre = require("hardhat");

const { VAT,
    SPOT,
    aBNBc,
    USB,
    UsbJoin,
    aBNBcJoin,
    Oracle,
    JUG,
    REAL_ABNBC,
    ceBNBc,
    REALaBNBcJoin,
    REWARDS,
    HELIO_TOKEN, INTERACTION,
    COLLATERAL_ABNBC,
    COLLATERAL_REAL_ABNBC,
    COLLATERAL_CE_ABNBC,
} = require('../../addresses-stage.json');
const {ethers} = require("hardhat");

async function main() {
    console.log('Running deploy script');

    this.HelioToken = await hre.ethers.getContractFactory("HelioToken");
    this.HelioRewards = await hre.ethers.getContractFactory("HelioRewards");

    const helioToken = await this.HelioToken.deploy();
    await helioToken.deployed();
    console.log("helioToken deployed to:", helioToken.address);

    const rewards = await this.HelioRewards.deploy(VAT);
    await rewards.deployed();
    console.log("Rewards deployed to:", rewards.address);

    console.log('Adding rewards pool');
    let collateral = ethers.utils.formatBytes32String(COLLATERAL_ABNBC);
    let collateral2 = ethers.utils.formatBytes32String(COLLATERAL_REAL_ABNBC);
    let collateral3 = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);

    await helioToken.rely(rewards.address);
    await rewards.setHelioToken(helioToken.address);
    await rewards.initPool(aBNBc, collateral, "1000000001847694957439350500"); //6%
    await rewards.initPool(REAL_ABNBC, collateral2, "1000000001847694957439350500"); //6%
    await rewards.initPool(ceBNBc, collateral3, "1000000001847694957439350500"); //6%

    console.log('Validating code');

    await hre.run("verify:verify", {
        address: rewards.address,
        constructorArguments: [
            VAT
        ],
    });
    await hre.run("verify:verify", {
        address: helioToken.address,
    });

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
