const {ethers, upgrades} = require("hardhat");


async function main() {
    console.log('Running deploy script');
    let [owner] = await ethers.getSigners();
    const Oracle = await hre.ethers.getContractFactory("MultiOracleMock");
    const oracle = await Oracle.deploy();
    await oracle.waitForDeployment();

    //await hre.run("verify:verify", {address: oracle.target});

    console.log('oracle deploy at', oracle.target);

    let hasRole = await oracle.hasRole('0x73e573f9566d61418a34d5de3ff49360f9c51fec37f7486551670290f6285dab', owner);
    console.log('DEPLOYER: %s has ADMIN_ROLE: %s', owner.address, hasRole);
    console.log('Finished');

}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
