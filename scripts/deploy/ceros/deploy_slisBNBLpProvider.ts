import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy SlisBNBLpProvider start network: ", hre.network.name);

    let certToken = '', collateralToken = '', daoAddress = '', collateralReserveAddress = '', proxy = '', guardian = '', userCollateralRate = ''
    if (hre.network.name === "bsc") {
        collateralToken = '0x4b30fcAA7945fE9fDEFD2895aae539ba102Ed6F6'
        certToken = '0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B'
        daoAddress = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
        collateralReserveAddress = '' // fixme
        proxy = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
        guardian = '0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8' // fixme
        userCollateralRate = 95e16.toFixed()
    } else if (hre.network.name === "bsc_testnet") {
        collateralToken = '0x3dC5a40119B85d5f2b06eEC86a6d36852bd9aB52'
        certToken = '0xCc752dC4ae72386986d011c2B485be0DAd98C744'
        daoAddress = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        collateralReserveAddress = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        proxy = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        guardian = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        userCollateralRate = 95e16.toFixed()
    }

    /**
     *        address collateralToken,
     *         address certToken,
     *         address daoAddress,
     *         address collateralReserveAddress,
     *         address proxy,
     *         address guardian,
     *         uint128 userCollateralRate
     *         */
    // testnet address 241016: 0x7611100aD86633fCEdCA1a9000b5a7B5D75f9b2F
    let contractFactory = await hre.ethers.getContractFactory("SlisBNBLpProvider");
    const ytslisBNBStakeVault = await upgrades.deployProxy(contractFactory, [
        collateralToken, certToken, daoAddress, collateralReserveAddress, proxy, guardian, userCollateralRate
    ], {initializer: "initialize"})

    console.log("Deployed: SlisBNBLpProvider: " + await ytslisBNBStakeVault.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
