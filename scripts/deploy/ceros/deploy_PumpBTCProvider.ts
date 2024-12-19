import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {
    console.log("deploy PumpBTCProvider start network: ", hre.network.name);
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    let manager = '', pauser = ''
    let ceToken = '', lpToken = '', daoAddress = '', pumpBTC = ''

    if (hre.network.name === "bsc") {
        manager = '0x8d388136d578dCD791D081c6042284CED6d9B0c6'
        pauser = '0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8'
        daoAddress = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4'
        pumpBTC = '0xf9C4FF105803A77eCB5DAE300871Ad76c2794fa4'
        ceToken = '0xc6F28a668b7c18F921ccBA4adc3D8db72BFF0FE2' // cePumpBTC
        lpToken = '0x8A314300088ec75AAEFc53B92F73819050182CC6' // clisPumpBTC
    } else if (hre.network.name === "bsc_testnet" || hre.network.name === "bscLocal") {
        manager = '0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06'
        pauser = '0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06'
        daoAddress = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279'
        pumpBTC = '0x6858f3fe341f8A8D3bC922D52EBe12C0ee5d1C59'
        ceToken = '0xF95144b8aeFeeD7cBea231D24Be53766223Ad5f0'
        lpToken = '0x40c41c209432Fb5620106c3c91485a807AD99DcD'
    }

    // testnet address : 0xBeff3263A9B260108004cbf569236da6E50F16cf
    let contractFactory = await hre.ethers.getContractFactory("PumpBTCProvider");
    const pumpBTCProvider = await upgrades.deployProxy(contractFactory, [
        deployer, manager, pauser, lpToken, ceToken, pumpBTC, daoAddress
    ], {initializer: "initialize"})

    const pumpBTCProviderAddress = await pumpBTCProvider.getAddress()

    console.log("Deployed: PumpBTCProvider: " + pumpBTCProviderAddress)

    // ceToken add minter
    const CeToken = await ethers.getContractFactory("CeToken");
    const ceTokenIntance = CeToken.attach(ceToken);
    await ceTokenIntance.changeVault(pumpBTCProviderAddress);
    console.log("CeToken: added minter " + pumpBTCProviderAddress);

    // lpToken add minter
    const LpToken = await ethers.getContractFactory("ClisToken");
    const lpTokenIntance = LpToken.attach(lpToken);
    await lpTokenIntance.addMinter(pumpBTCProviderAddress);
    console.log("LpToken: added minter " + pumpBTCProviderAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
