import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy FDUSDLpProvider start network: ", hre.network.name);
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    let proxy = '', pauser = ''
    let certToken = '', collateralToken = '', daoAddress = ''
    if (hre.network.name === "bsc") {
        pauser = '0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8'
        proxy = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4' // interaction
        collateralToken = '' // fixme: clisFDUSD mainnet
        certToken = '0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409'
        daoAddress = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
    } else if (hre.network.name === "bsc_testnet") {
        pauser = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        proxy = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        collateralToken = '0x13829fDFFd98a8337A8a10b01A1aD0904E35167B'
        certToken = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af' // use lisusd instead
        daoAddress = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
    }

    // testnet address 241017: 0xbF977ae8965Cd8Cc6EeE934264aC2cc198e3c613
    let contractFactory = await hre.ethers.getContractFactory("FDUSDLpProvider");
    const ytslisBNBStakeVault = await upgrades.deployProxy(contractFactory, [
        deployer, proxy, pauser, collateralToken, certToken, daoAddress
    ], {initializer: "initialize"})

    console.log("Deployed: FDUSDLpProvider: " + await ytslisBNBStakeVault.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
