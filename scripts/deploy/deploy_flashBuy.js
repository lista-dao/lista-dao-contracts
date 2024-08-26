const hre = require("hardhat");
const {upgrades} = require("hardhat");

async function main() {
    // Contracts Fetching
    let FlashBuy = await hre.ethers.getContractFactory("FlashBuy");
    const lender = "0x64d94e715B6c03A5D8ebc6B2144fcef278EC6aAa";
    const interaction = "0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4";
    const dex = "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4";

    const flashBuy = await upgrades.deployProxy(FlashBuy, [
        lender,
        interaction,
        dex
    ], {initializer: "initialize"})

    console.log("Deployed: FlashBuy: " + await flashBuy.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
