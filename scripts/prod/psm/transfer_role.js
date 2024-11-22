const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')
const Promise = require("bluebird");

let MANAGER_ROLE = '0xaf290d8680820aad922855f39b306097b20e28774d6c1ad35a20325630c3a02c';
let ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const admin = '0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253';
    const manager = '0x8d388136d578dCD791D081c6042284CED6d9B0c6';

    const psmAddress = '0x7E88e1208C6c23891D84E740b9883B7bcD6e7293';
    const vaultManagerAddress = '0x17A24F1b7e3ac0791721C98a8cC3c1d475d8c0eb';
    const venusAdapterAddress = '0x49EC09a680a749Ad6F4c266dc313Ef0dd3Abf783';
    const lisUSDPoolSetAddress = '0xA23FC5Cd5a1bC0fa7BcC90A89bdd1487ac8e3970';
    const earnPoolAddress = '0x710B256c7B20F5F115D57602590B076bb21d8241';

    const psmContract = await ethers.getContractAt('PSM', psmAddress);
    const vaultManagerContract = await ethers.getContractAt('VaultManager', vaultManagerAddress);
    const venusAdapterContract = await ethers.getContractAt('VenusAdapter', venusAdapterAddress);
    const lisUSDPoolSetContract = await ethers.getContractAt('LisUSDPoolSet', lisUSDPoolSetAddress);
    const earnPoolContract = await ethers.getContractAt('EarnPool', earnPoolAddress);

    await Promise.delay(3000);
    await psmContract.grantRole(MANAGER_ROLE, manager);
    await Promise.delay(3000);
    await psmContract.revokeRole(MANAGER_ROLE, deployer);
    await Promise.delay(3000);
    await psmContract.grantRole(ADMIN_ROLE, admin);
    await Promise.delay(3000);
    await psmContract.revokeRole(ADMIN_ROLE, deployer);
    console.log("psm role setup done");

    await Promise.delay(3000);
    await vaultManagerContract.grantRole(MANAGER_ROLE, manager);
    await Promise.delay(3000);
    await vaultManagerContract.revokeRole(MANAGER_ROLE, deployer);
    await Promise.delay(3000);
    await vaultManagerContract.grantRole(ADMIN_ROLE, admin);
    await Promise.delay(3000);
    await vaultManagerContract.revokeRole(ADMIN_ROLE, deployer);
    console.log("vaultManager role setup done");

    await Promise.delay(3000);
    await venusAdapterContract.grantRole(MANAGER_ROLE, manager);
    await Promise.delay(3000);
    await venusAdapterContract.revokeRole(MANAGER_ROLE, deployer);
    await Promise.delay(3000);
    await venusAdapterContract.grantRole(ADMIN_ROLE, admin);
    await Promise.delay(3000);
    await venusAdapterContract.revokeRole(ADMIN_ROLE, deployer);
    console.log("venusAdapter role setup done");

    await Promise.delay(3000);
    await lisUSDPoolSetContract.grantRole(MANAGER_ROLE, manager);
    await Promise.delay(3000);
    await lisUSDPoolSetContract.revokeRole(MANAGER_ROLE, deployer);
    await Promise.delay(3000);
    await lisUSDPoolSetContract.grantRole(ADMIN_ROLE, admin);
    await Promise.delay(3000);
    await lisUSDPoolSetContract.revokeRole(ADMIN_ROLE, deployer);
    console.log("lisUSDPoolSet role setup done");

    await Promise.delay(3000);
    await earnPoolContract.grantRole(MANAGER_ROLE, manager);
    await Promise.delay(3000);
    await earnPoolContract.revokeRole(MANAGER_ROLE, deployer);
    await Promise.delay(3000);
    await earnPoolContract.grantRole(ADMIN_ROLE, admin);
    await Promise.delay(3000);
    await earnPoolContract.revokeRole(ADMIN_ROLE, deployer);
    console.log("earnPool role setup done");

    console.log('Transfer role done');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
