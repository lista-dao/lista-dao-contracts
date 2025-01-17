import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy clismBTC start network: ", hre.network.name);

    const name = 'Lista Collateral mBTC'
    const symbol = 'clismBTC'

    /**
     *         string name,
     *         string symbol,
     */
    // testnet address : 0x40c41c209432Fb5620106c3c91485a807AD99DcD
    let contractFactory = await hre.ethers.getContractFactory("ClisToken");
    const clisMBTC = await upgrades.deployProxy(contractFactory, [
        name, symbol
    ], {initializer: "initialize"})

    console.log("Deployed: clismBTC: " + await clisMBTC.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
