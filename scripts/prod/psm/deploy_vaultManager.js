const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let usdt = '0x55d398326f99059fF775485246999027B3197955';

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    const admin = deployer;
    const manager = deployer;
    const token = usdt;
    const psmAddress = "0xaa57F36DD5Ef2aC471863ec46277f976f272eC0c";
    const VaultManager = await hre.ethers.getContractFactory('VaultManager');
    const vaultManager = await upgrades.deployProxy(VaultManager, [
        admin,
        manager,
        psmAddress,
        token
    ]);
    await vaultManager.waitForDeployment();

    const vaultManagerAddress = await vaultManager.getAddress();

    try {
        await run("verify:verify", {
            address: vaultManagerAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    const psmContract = await ethers.getContractAt('PSM', psmAddress);

    await psmContract.setVaultManager(vaultManagerAddress);

    console.log(`VaultManager USDT deployed to:`, vaultManagerAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
