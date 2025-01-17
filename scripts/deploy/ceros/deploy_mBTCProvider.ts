import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy mBTCProvider start network: ", hre.network.name);
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    let manager = '', pauser = ''
    let ceToken = '', lpToken = '', daoAddress = '', mBTC = ''

    if (hre.network.name === "bsc") {
        manager = '0x8d388136d578dCD791D081c6042284CED6d9B0c6'
        pauser = '0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8'
        daoAddress = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
        mBTC = '0x7c1cCA5b25Fa0bC9AF9275Fb53cBA89DC172b878'
        ceToken = '' // cemBTC
        lpToken = '' // clismBTC
    } else if (hre.network.name === "bsc_testnet" || hre.network.name === "bscLocal") {
        manager = '0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06'
        pauser = '0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06'
        daoAddress = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        mBTC = '0x85973410B4BBF1Ad39a339532e82B3d1db54e2c4'
        ceToken = '0x6F805B6548EaF0dC412fD4FA531183b8dD809145'
        lpToken = '0x90d65Aa791f7406d46DF280DBb4E8bCe6AC03fef'
    }

    // testnet address : 0xBeff3263A9B260108004cbf569236da6E50F16cf
    let contractFactory = await hre.ethers.getContractFactory("mBTCProvider");
    const mBTCProvider = await upgrades.deployProxy(contractFactory, [
        deployer, manager, pauser, lpToken, ceToken, mBTC, daoAddress
    ], {initializer: "initialize"})

    const mBTCProviderAddress = await mBTCProvider.getAddress()

    console.log("Deployed: PumpBTCProvider: " + mBTCProviderAddress)

    // ceToken add minter
    const CeToken = await ethers.getContractFactory("CeToken");
    const ceTokenIntance = CeToken.attach(ceToken);
    await ceTokenIntance.changeVault(mBTCProviderAddress);
    console.log("CeToken: added minter " + mBTCProviderAddress);

    // lpToken add minter
    const LpToken = await ethers.getContractFactory("ClisToken");
    const lpTokenIntance = LpToken.attach(lpToken);
    await lpTokenIntance.addMinter(mBTCProviderAddress);
    console.log("LpToken: added minter " + mBTCProviderAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
