const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let psm = '0xA0a4D7c3282B55Ef88a12AE394f00E9e47487651';
let usdc = '0xA528b0E61b72A0191515944cD8818a88d1D1D22b';

async function main() {
    const VaultManager = await hre.ethers.getContractFactory('VaultManager');
    const vaultManager = await upgrades.deployProxy(VaultManager, [
        psm,
       usdc
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
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
