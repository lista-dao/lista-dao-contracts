const { upgradeProxy , deployImplementation , verifyImpContract , getProxyAdminAddress } = require("./utils/upgrade_utils")
const { ethers, upgrades} = require('hardhat')
const hre = require("hardhat");

const networkName = hre.network.name

const contractName = "CerosETHRouter";
const proxyAddress = networkName === "bsc" ? "0xA0cD5EAfa37EBA1d04Fb003512f962f2f73C3e86" : "0x1623369790488fDFaCD315a8378F3E35F7825b33";

const main = async () => {
    console.log("start upgrade ", networkName);
    const CerosETHRouter = await ethers.getContractFactory(contractName)
    const CerosETHRouterOld = await ethers.getContractFactory('CerosETHRouterOld')

    console.log("start forceImport");
    await upgrades.forceImport(proxyAddress, CerosETHRouterOld, { kind: 'transparent' });

    console.log("start validateUpgrade");
    await upgrades.validateUpgrade(
        proxyAddress
        , CerosETHRouter
        , { unsafeAllow: ['external-library-linking'] })
    console.log('Upgradability is validated successfully.')


    // upgrade Proxy
    if (networkName === "bsc_testnet") {
        console.log("upgradeProxy...")
        await upgrades.upgradeProxy(proxyAddress, CerosETHRouter, {unsafeAllow: ["external-library-linking"]});
    } else {
        // deploy Implementation
        const impAddress = await deployImplementation(contractName);
        console.log("deployImplementation ok, address: ", impAddress);

        console.log("upgradeProxy skip mainnet...")

        console.log("verifyImpContract...")
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
