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
    REWARDS,
    HELIO_TOKEN, INTERACTION
} = require('../../addresses.json');
const {ethers} = require("hardhat");

async function main() {
    console.log('Running deploy script');

    this.HelioToken = await hre.ethers.getContractFactory("HelioToken");
    this.HelioRewards = await hre.ethers.getContractFactory("HelioRewards");

    const helioToken = await this.HelioToken.deploy();
    await helioToken.waitForDeployment();
    console.log("helioToken deployed to:", helioToken.target);

    const rewards = await this.HelioRewards.deploy(VAT);
    await rewards.waitForDeployment();
    console.log("Rewards deployed to:", rewards.target);

    console.log('Adding rewards pool');
    let collateral = ethers.encodeBytes32String("aBNBc");

    await helioToken.rely(rewards.target);
    await rewards.setHelioToken(helioToken.target);
    await rewards.initPool(aBNBc, collateral, "1000000001847694957439350500"); //6%
    await rewards.connect(deployer).rely(interaction.target);

    console.log('Validating code');

    await hre.run("verify:verify", {
        address: REWARDS,
        constructorArguments: [
            VAT
        ],
    });
    await hre.run("verify:verify", {
        address: HELIO_TOKEN,
    });

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
