const {ethers, upgrades} = require("hardhat");


async function main() {
    console.log('Running deploy script');

    const Oracle = await hre.ethers.getContractFactory("MockPriceFeed");
    const oracle = await Oracle.deploy();
    await oracle.waitForDeployment();

    await hre.run("verify:verify", {address: oracle.target});

    console.log('oracle deploy at', oracle.target);

}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
