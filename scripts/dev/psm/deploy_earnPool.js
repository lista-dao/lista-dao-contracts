const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let psm = '0xF73713Cf3187e2Ce913d72ff0D2E53A4982a445C';
let lisUSDPool = '0xACba0906B593C2F482386a8109961D9a93B095a7';
let gem = '0xA528b0E61b72A0191515944cD8818a88d1D1D22b';
let lisUSD = '0x7adC9A28Fab850586dB99E7234EA2Eb7014950fA';

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const EarnPool = await hre.ethers.getContractFactory('EarnPool');
    const earnPoll = await upgrades.deployProxy(EarnPool, [
        'Lista USDC Earn Pool',
        'lisUSDCEarn',
        psm,
        lisUSDPool,
        gem,
        lisUSD,
    ]);
    await earnPoll.waitForDeployment();

    const proxyAddress = await earnPoll.getAddress();

    console.log('EarnPool deployed to:', proxyAddress);
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
