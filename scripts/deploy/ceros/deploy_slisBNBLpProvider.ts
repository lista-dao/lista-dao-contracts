import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy SlisBNBLpProvider start network: ", hre.network.name);
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    let proxy = '', pauser = ''
    let certToken = '', collateralToken = '', daoAddress = '', collateralReserveAddress = ''
    let userCollateralRate = '', exchangeRate = ''
    if (hre.network.name === "bsc") {
        pauser = '0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8'
        proxy = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4' // interaction
        collateralToken = '0x4b30fcAA7945fE9fDEFD2895aae539ba102Ed6F6'
        certToken = '0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B'
        daoAddress = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
        collateralReserveAddress = '' // fixme
        exchangeRate = 1022e15.toFixed()
        userCollateralRate = 95e16.toFixed()
    } else if (hre.network.name === "bsc_testnet" || hre.network.name === "bscLocal") {
        pauser = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        proxy = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        collateralToken = '0x3dC5a40119B85d5f2b06eEC86a6d36852bd9aB52'
        certToken = '0xCc752dC4ae72386986d011c2B485be0DAd98C744'
        daoAddress = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        collateralReserveAddress = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        exchangeRate = 1022e15.toFixed()
        userCollateralRate = 95e16.toFixed()
    }

    // testnet address 241017: 0x8AE7BFF744fd91c8f033125a54fAdD1430256B78
    let contractFactory = await hre.ethers.getContractFactory("SlisBNBLpProvider");
    const ytslisBNBStakeVault = await upgrades.deployProxy(contractFactory, [
        deployer, proxy, pauser, collateralToken, certToken, daoAddress, collateralReserveAddress, exchangeRate, userCollateralRate
    ], {initializer: "initialize"})

    console.log("Deployed: SlisBNBLpProvider: " + await ytslisBNBStakeVault.getAddress())
    /**
     *        address _admin,
     *         address _manager,
     *         address _pauser,
     *         address _collateralToken,
     *         address _certToken,
     *         address _daoAddress,
     *         address _collateralReserveAddress,
     *         uint128 _exchangeRate,
     *         uint128 _userCollateralRate
     */
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
