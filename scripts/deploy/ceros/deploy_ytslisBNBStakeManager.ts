import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy ytslisBNBStakeManager start network: ", hre.network.name);
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    let manager = '', pauser = '', certToken = '', reserveAddress, collateralToken = ''
        , exchangeRate = '', userCollateralRate = '';
    if (hre.network.name === "bsc") {
        manager = '0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8'
        pauser = '0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8'
        certToken = '' // ytslisBNB address
        collateralToken = '0x4b30fcaa7945fe9fdefd2895aae539ba102ed6f6'
        reserveAddress = '' // fixme
        exchangeRate = 1022e15.toFixed()
        userCollateralRate = 95e16.toFixed()
    } else if (hre.network.name === "bsc_testnet") {
        manager = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        pauser = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        certToken = '0xCc752dC4ae72386986d011c2B485be0DAd98C744' // use slisbnb instead
        collateralToken = '0x3dC5a40119B85d5f2b06eEC86a6d36852bd9aB52'
        reserveAddress = '0xeA71Ec772B5dd5aF1D15E31341d6705f9CB86232'
        exchangeRate = 1022e15.toFixed()
        userCollateralRate = 95e16.toFixed()
    }

    // testnet address 241016: 0x1551a172f9096d364E05c2Ae658119E02A7f1DCA
    let contractFactory = await hre.ethers.getContractFactory("ytslisBNBStakeManager");
    const ytslisBNBStakeVault = await upgrades.deployProxy(contractFactory, [
        deployer, manager, pauser, certToken, collateralToken, reserveAddress, exchangeRate, userCollateralRate
    ], {initializer: "initialize"})
    console.log("Deployed: ytslisBNBStakeManager: " + await ytslisBNBStakeVault.getAddress())
    /**
     *        address _admin,
     *         address _manager,
     *         address _pauser,
     *         address _certToken,
     *         address _collateralToken,
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
