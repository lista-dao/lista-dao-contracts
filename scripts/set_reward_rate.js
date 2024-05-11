const {BN} = require("@openzeppelin/test-helpers");
const {JUG, aBNBc, ceBNBc, VAT, REWARDS} = require("../addresses.json");
const {ethers} = require("hardhat");
const hre = require("hardhat");

async function main() {
    console.log('Running deploy script');

    this.HelioRewards = await hre.ethers.getContractFactory("HelioRewards");
    const rewards = this.HelioRewards.attach(REWARDS);

    let abnbcCollateral = ethers.utils.formatBytes32String("aBNBc");
    let ceTokenCollateral = ethers.utils.formatBytes32String("ceToken");

    await rewards.initPool(aBNBc, abnbcCollateral, "1000000001847694957439350500"); //6%
    await rewards.initPool(ceBNBc, ceTokenCollateral, "1000000001847694957439350500"); //6%

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

