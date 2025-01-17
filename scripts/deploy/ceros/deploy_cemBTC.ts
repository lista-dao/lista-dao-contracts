import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy cemBTC start network: ", hre.network.name);

    const name = 'Lista cemBTC'
    const symbol = 'cemBTC'

    /**
     *         string name,
     *         string symbol,
     */
    // testnet address : 0xF95144b8aeFeeD7cBea231D24Be53766223Ad5f0
    let contractFactory = await hre.ethers.getContractFactory("CeToken");
    const ceMBTC = await upgrades.deployProxy(contractFactory, [
        name, symbol
    ], {initializer: "initialize"})

    console.log("Deployed: cemBTC: " + await ceMBTC.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
