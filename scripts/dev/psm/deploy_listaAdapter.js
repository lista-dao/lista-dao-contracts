const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let USDC = '0xadbccCa89eC498F8B9B7F6A4B05206b113676861';
let vaultManager = '0x218d35E5a3972Bd9D0E48007054603CFf9922aAA';

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
