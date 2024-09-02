const { upgradeProxy , deployImplementation , verifyImpContract , getProxyAdminAddress } = require("./utils/upgrade_utils")
const { ethers, upgrades} = require('hardhat')
const hre = require("hardhat");

const networkName = hre.network.name

const contractName = "CeETHVault";
const proxyAddress = networkName === "bsc" ? "0xA230805C28121cc97B348f8209c79BEBEa3839C0" : "0x2d924a915B1d9a6926366149f8d39509f7D501bB";

const main = async () => {
    console.log("start upgrade CeETHVault", networkName);
    const ceETHVault = await ethers.getContractFactory(contractName)
    const ceETHVaultOld = await ethers.getContractFactory('CeETHVaultOld')

    console.log("start forceImport");
    await upgrades.forceImport(proxyAddress, ceETHVaultOld, { kind: 'transparent' });

    console.log("start validateUpgrade");
    await upgrades.validateUpgrade(
        proxyAddress
        , ceETHVault
        , { unsafeAllow: ['external-library-linking'] })
    console.log('Upgrade validated successfully.')

    // upgrade Proxy
    if (networkName === "bsc_testnet") {
        console.log("upgradeProxy...")
        await upgrades.upgradeProxy(proxyAddress, ceETHVault, {unsafeAllow: ["external-library-linking"]});
    } else {
        // deploy Implementation
        const impAddress = await deployImplementation(contractName);
        console.log(`deployImplementation ok, address: ${impAddress}`);

        console.log("upgradeProxy skip mainnet...")

        console.log(`verifyImpContract at ${impAddress}...`)
        await verifyImpContract(impAddress);
    }
};

main()
    .then(() => {
        console.log("Success");
    })
    .catch((err) => {
        console.log(err);
    });
