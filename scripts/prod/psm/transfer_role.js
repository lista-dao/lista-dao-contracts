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

    const psmAddress = '';
    const vaultManagerAddress = '';
    const venusAdapterAddress = '';
    const lisUSDPoolSetAddress = '';
    const earnPoolAddress = '';

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
