const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let usdt = '0x55d398326f99059fF775485246999027B3197955';
let lisUSD = '0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5';
let sellFee = 0; // 0%
let buyFee = 200; // 2%
let dailyLimit = '500000000000000000000000' // 500k;
let minSell = '1000000000000000000'; // 1u;
let minBuy = '1000000000000000000'; // 1u;
const pauser = "0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8";
const feeReceiver = "0x34B504A5CF0fF41F8A480580533b6Dda687fa3Da";

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    const admin = deployer;
    const manager = deployer;
    const token = usdt;
    // deploy PSM (name)
    const PSM = await hre.ethers.getContractFactory('PSM');
    const psm = await upgrades.deployProxy(PSM, [
        admin,
        manager,
        pauser,
        token,
        feeReceiver,
        lisUSD,
        sellFee,
        buyFee,
        dailyLimit,
        minSell,
        minBuy
    ]);
    await psm.waitForDeployment();

    const psmAddress = await psm.getAddress();

    try {
        await run("verify:verify", {
            address: psmAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    console.log(`PSM (USDT) deployed to:`, psmAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
