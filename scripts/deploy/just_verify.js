const fs = require("fs");
const path = require("path");
const {ethers, upgrades} = require("hardhat");

// Global Variables
let rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {
    await hre.run("verify:verify", {address: "0x4Bb08858bc554043C157B7d7138F0cFf98Be66DC"});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
