const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let USDC = '0xA528b0E61b72A0191515944cD8818a88d1D1D22b';
let vaultManager = '0x08bEBa90fD5856351F6864e14C323639A547a856';

async function main() {
    const ListaAdapter = await hre.ethers.getContractFactory('ListaAdapter');
    const listaAdapter = await upgrades.deployProxy(ListaAdapter, [
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

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
