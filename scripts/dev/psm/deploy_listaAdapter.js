const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let USDC = '0xA528b0E61b72A0191515944cD8818a88d1D1D22b';
let vaultManager = '0x181DEC72eA77D01b01f283597Ed3CB0A2B6a9858';

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const ListaAdapter = await hre.ethers.getContractFactory('ListaAdapter');
    const listaAdapter = await upgrades.deployProxy(ListaAdapter, [
        deployer,
        deployer,
        USDC,
        vaultManager
    ]);
    await listaAdapter.waitForDeployment();

    const proxyAddress = await listaAdapter.getAddress();

    console.log('ListaAdapter deployed to:', proxyAddress);
    try {
        await run("verify:verify", {
            address: proxyAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    const vaultManagerContract = await ethers.getContractAt('VaultManager', vaultManager);

    await vaultManagerContract.addAdapter(proxyAddress, 100);

    console.log('ListaAdapter deploy and setup done');

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
