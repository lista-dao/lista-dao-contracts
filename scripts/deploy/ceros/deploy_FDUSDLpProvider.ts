import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy FDUSDLpProvider start network: ", hre.network.name);

    let certToken = '', collateralToken = '', daoAddress = '', proxy = '', guardian = ''
    if (hre.network.name === "bsc") {
        collateralToken = '' // fixme: clisFDUSD mainnet
        certToken = '0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409'
        daoAddress = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
        proxy = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
        guardian = '0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8' // fixme
    } else if (hre.network.name === "bsc_testnet") {
        collateralToken = '0x13829fDFFd98a8337A8a10b01A1aD0904E35167B'
        certToken = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af' // use lisusd instead
        daoAddress = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        proxy = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        guardian = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
    }
    /**
     *        address collateralToken,
     *         address certToken,
     *         address daoAddress,
     *         address proxy,
     *         address guardian
     */
    // testnet address 241016: 0xBBca22371D798630acf9E9c70A4B7894531557b4
    let contractFactory = await hre.ethers.getContractFactory("FDUSDLpProvider");
    const ytslisBNBStakeVault = await upgrades.deployProxy(contractFactory, [
        collateralToken, certToken, daoAddress, proxy, guardian
    ], {initializer: "initialize"})

    console.log("Deployed: FDUSDLpProvider: " + await ytslisBNBStakeVault.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
