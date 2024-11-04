const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let psm = '0x89F5e21Ed5d716FcD86dfF00fDAbf9Bbc9327AC5';
let usdc = '0xA528b0E61b72A0191515944cD8818a88d1D1D22b';

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
