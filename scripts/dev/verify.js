const {ethers, upgrades} = require("hardhat");

const {
    VAT,
    SPOT,
    HAY,
    HayJoin,
    ceBNBcJoin,
    JUG,
    CLIP,
    REWARDS,
    VOW,
    HELIO_ORACLE,
    HELIO_TOKEN,
    AUCTION_PROXY, CLIP1, CLIP3,
    INTERACTION, aBNBcJoin, aBNBc,
    DOG, DEPLOYER, ceBNBc,CE_ABNBC_ILK, FAKE_ABNBC_ILK,
} = require('../../addresses.json');

async function main() {

    let collateralCE = CE_ABNBC_ILK;
    let collateralFAKE = FAKE_ABNBC_ILK;

    // CODE VERIFICATION
    console.log('Validating code');
    let vatImplAddress = await upgrades.erc1967.getImplementationAddress(VAT);
    console.log("vatImplAddress implementation: ", vatImplAddress);

    await hre.run("verify:verify", {
        address: vatImplAddress
    });
    await hre.run("verify:verify", {
        address: SPOT,
        constructorArguments: [
            VAT
        ],
    });
    await hre.run("verify:verify", {
        address: HayJoin,
        constructorArguments: [
            VAT,
            HAY
        ],
    });
    await hre.run("verify:verify", {
        address: ceBNBcJoin,
        constructorArguments: [
            VAT,
            collateralCE,
            ceBNBc,
        ],
    });
    await hre.run("verify:verify", {
        address: aBNBcJoin,
        constructorArguments: [
            VAT,
            collateralFAKE,
            aBNBc,
        ],
    });
    await hre.run("verify:verify", {
        address: JUG,
        constructorArguments: [
            VAT,
        ],
    });
    await hre.run("verify:verify", {
        address: VOW,
        constructorArguments: [
            VAT,
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            DEPLOYER
        ],
    });
    await hre.run("verify:verify", {
        address: DOG,
        constructorArguments: [
            VAT,
        ],
    });
    await hre.run("verify:verify", {
        address: CLIP1,
        constructorArguments: [
            VAT,
            SPOT,
            DOG,
            collateralFAKE
        ],
    });
    await hre.run("verify:verify", {
        address: CLIP3,
        constructorArguments: [
            VAT,
            SPOT,
            DOG,
            collateralCE
        ],
    });
    // Rewards
    let rewardsImplAddress = await upgrades.erc1967.getImplementationAddress(REWARDS);
    console.log("rewardsImplAddress implementation: ", rewardsImplAddress);
    await hre.run("verify:verify", {
        address: rewardsImplAddress,
    });
    await hre.run("verify:verify", {
        address: HAY,
        constructorArguments: [
            97,
            "HAY"
        ],
    });

    // let oracleImplAddress = await upgrades.erc1967.getImplementationAddress(HELIO_ORACLE);
    // console.log("rewardsImplAddress implementation: ", oracleImplAddress);
    // await hre.run("verify:verify", {
    //     address: oracleImplAddress,
    // });
    // await hre.run("verify:verify", {
    //     address: HELIO_TOKEN,
    //     constructorArguments: [
    //         "100000000",
    //         REWARDS,
    //     ],
    // });

    // Interaction
    await hre.run("verify:verify", {
        address: AUCTION_PROXY
    });

    // await hre.run("verify:verify", {
    //     address: INTERACTION
    // });

    let interactionImplAddress = await upgrades.erc1967.getImplementationAddress(INTERACTION);
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
