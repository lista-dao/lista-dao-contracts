const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let psm = '0x7616c413F29059D5002B0cCdFc2c82526EdA3E23';
let usdc = '0xadbccCa89eC498F8B9B7F6A4B05206b113676861';

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const VaultManager = await hre.ethers.getContractFactory('VaultManager');
    const vaultManager = await upgrades.deployProxy(VaultManager, [
        deployer,
        deployer,
        psm,
        usdc,
        deployer
    ]);
    await vaultManager.waitForDeployment();

    const proxyAddress = await vaultManager.getAddress();

    console.log('VaultManager deployed to:', proxyAddress);
    try {
        await run("verify:verify", {
            address: proxyAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    const psmContract = await ethers.getContractAt('PSM', psm);

    await psmContract.setVaultManager(proxyAddress);

    console.log('VaultManager deploy and setup done');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
