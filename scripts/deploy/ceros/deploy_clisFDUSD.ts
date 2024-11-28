import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy clisFDUSD start network: ", hre.network.name);

    const name = 'Lista Collateral FDUSD'
    const symbol = 'clisFDUSD'

    /**
     *         string name,
     *         string symbol,
     */
    // testnet address 241016: 0x13829fDFFd98a8337A8a10b01A1aD0904E35167B
    let contractFactory = await hre.ethers.getContractFactory("ClisToken");
    const ytslisBNBStakeVault = await upgrades.deployProxy(contractFactory, [
        name, symbol
    ], {initializer: "initialize"})

    console.log("Deployed: clisFDUSD: " + await ytslisBNBStakeVault.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
