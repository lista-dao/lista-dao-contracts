const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

async function main() {
    const MockUSDCFactory = await hre.ethers.getContractFactory('MockUSDC');
    const mockUSDC = await MockUSDCFactory.deploy('USDC', 'USDC');
    await mockUSDC.deploymentTransaction().wait(6);
    const address = await mockUSDC.getAddress();

    console.log('MockUSDC deployed to:', address);
    await run("verify:verify", {
        address,
        constructorArguments: ['USDC', 'USDC'],
        contract: 'contracts/mock/MockUSDC.sol:MockUSDC'
    });

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
