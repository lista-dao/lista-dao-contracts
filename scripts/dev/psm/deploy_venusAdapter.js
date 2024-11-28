const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let token = '0xadbccCa89eC498F8B9B7F6A4B05206b113676861';
let vaultManager = '0x107fCA953BAbc1962A5c29F66aa615a6cf3c99Da';
let vToken = '0x69D7Bc4A60b342C9811915f9628035A72C81EC60';

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    const admin = deployer;
    const manager = deployer;
    const feeReceiver = deployer;

    const ListaAdapter = await hre.ethers.getContractFactory('VenusAdapter');
    const listaAdapter = await upgrades.deployProxy(ListaAdapter, [
        admin,
        manager,
        vaultManager,
        token,
        vToken,
        feeReceiver
    ]);
    await listaAdapter.waitForDeployment();

    const proxyAddress = await listaAdapter.getAddress();

    console.log('VenusAdapter deployed to:', proxyAddress);
    try {
        await run("verify:verify", {
            address: proxyAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    const vaultManagerContract = await ethers.getContractAt('VaultManager', vaultManager);

    await vaultManagerContract.addAdapter(proxyAddress, 100);

    console.log('VenusAdapter deploy and setup done');

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
