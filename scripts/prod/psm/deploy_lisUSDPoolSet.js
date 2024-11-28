const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')
const Promise = require("bluebird");

let pauser = "0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8";
let lisUSD = '0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5';
let bot = '0x3995852eb0C4E8b1aA4cB31dDAC254ff199111ff';
let mutiSigManager = '0x8d388136d578dCD791D081c6042284CED6d9B0c6';
let maxDuty = '1000000004431822000000000000'; // 15%
let maxAmount = "30000000000000000000000000"; // 30m
let duty = '1000000001847694957439352158'; // 6%
let withdrawDelay = 5;
let BOT_ROLE = '0x902cbe3a02736af9827fb6a90bada39e955c0941e08f0c63b3a662a7b17a4e2b';

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    const admin = deployer;
    const manager = deployer;
    const LisUSDPool = await hre.ethers.getContractFactory('LisUSDPoolSet');
    const lisUSDPool = await upgrades.deployProxy(LisUSDPool, [
        admin,
        manager,
        pauser,
        bot,
        lisUSD,
        maxDuty,
        withdrawDelay
    ]);
    await lisUSDPool.waitForDeployment();

    const lisUSDPoolAddress = await lisUSDPool.getAddress();

    try {
        await run("verify:verify", {
            address: lisUSDPoolAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    const LisUSDPoolContract = await ethers.getContractAt('LisUSDPoolSet', lisUSDPoolAddress);

    await LisUSDPoolContract.setMaxAmount(maxAmount);
    await Promise.delay(3000);
    await LisUSDPoolContract.grantRole(BOT_ROLE, deployer);
    await Promise.delay(3000);
    await LisUSDPoolContract.setDuty(duty);
    await Promise.delay(3000);
    await LisUSDPoolContract.revokeRole(BOT_ROLE, deployer);
    await Promise.delay(3000);
    await LisUSDPoolContract.grantRole(BOT_ROLE, mutiSigManager);
    await Promise.delay(3000);

    console.log('LisUSDPool deployed to:', lisUSDPoolAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
