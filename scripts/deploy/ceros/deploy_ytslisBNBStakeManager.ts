import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy ytslisBNBStakeManager start network: ", hre.network.name);

    let admin = '', manager = '', pauser = '', certToken = '', reserveAddress, collateralToken = '', exchangeRate = '',
        userCollateralRate = '';
    if (hre.network.name === "bsc") {
        admin = ''
        manager = ''
        pauser = ''
        certToken = '' // ytslisBNB address
        collateralToken = '0x4b30fcaa7945fe9fdefd2895aae539ba102ed6f6'
        reserveAddress = ''
        exchangeRate = BigInt(1e18).toString()
        userCollateralRate = BigInt(1e18).toString()
    } else if (hre.network.name === "bsc_testnet") {
        admin = '0x05E3A7a66945ca9aF73f66660f22ffB36332FA54'
        manager = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        pauser = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        certToken = '0xCc752dC4ae72386986d011c2B485be0DAd98C744' // use slisbnb instead
        collateralToken = '0x3dC5a40119B85d5f2b06eEC86a6d36852bd9aB52'
        reserveAddress = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        exchangeRate = BigInt(1e18).toString()
        userCollateralRate = BigInt(1e18).toString()
    }

    /**
     *        address _admin,
     *         address _manager,
     *         address _pauser,
     *         address _certToken,
     *         address _collateralToken,
     *         address _collateralReserveAddress,
     *         uint128 _exchangeRate,
     *         uint128 _userCollateralRate
     *         */
    // testnet address 241016: 0xAbc25cff7DFe201F26Cdca0dd91ebEE3EfF2D9C3
    let contractFactory = await hre.ethers.getContractFactory("ytslisBNBStakeManager");
    const ytslisBNBStakeVault = await upgrades.deployProxy(contractFactory, [
        admin, manager, pauser, certToken, collateralToken, reserveAddress, exchangeRate, userCollateralRate
    ], {initializer: "initialize"})

    console.log("Deployed: ytslisBNBStakeManager: " + await ytslisBNBStakeVault.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
