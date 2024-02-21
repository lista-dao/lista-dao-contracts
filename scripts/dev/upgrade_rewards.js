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
    HELIO_TOKEN, INTERACTION, ceBNBc,
} = require('../../addresses.json');
const {ethers} = require("hardhat");

async function main() {
    console.log('Running deploy script');

    this.HelioToken = await hre.ethers.getContractFactory("HelioToken");
    this.HelioRewards = await hre.ethers.getContractFactory("HelioRewards");
    this.Interaction = await hre.ethers.getContractFactory("Interaction");

    const helioToken = this.HelioToken.attach(HELIO_TOKEN);
    const interaction = this.Interaction.attach(INTERACTION);

    const rewards = await this.HelioRewards.deploy(VAT);
    await rewards.waitForDeployment();
    console.log("Rewards deployed to:", rewards.target);

    await helioToken.rely(rewards.target);
    await rewards.setHelioToken(HELIO_TOKEN);
    await rewards.rely(INTERACTION);

    console.log('Adding rewards pool');
    let abnbcCollateral = ethers.encodeBytes32String("aBNBc");
    let ceTokenCollateral = ethers.encodeBytes32String("ceToken");

    await rewards.initPool(aBNBc, abnbcCollateral, "1000000001847694957439350500"); //6%
    await rewards.initPool(ceBNBc, ceTokenCollateral, "1000000001847694957439350500"); //6%

    interaction.setRewards(rewards.target);

    console.log('Validating code');

    await hre.run("verify:verify", {
        address: rewards.target,
        constructorArguments: [
            VAT
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
