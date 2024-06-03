const {ethers, upgrades} = require("hardhat");
const {transferProxyAdminOwner} = require("../upgrades/utils/upgrade_utils");


async function main() {
    console.log('Running deploy script');

    let [owner] = await ethers.getSigners();
    this.Oracle = await hre.ethers.getContractFactory("MultiOracleMock");

    let oracle = await upgrades.deployProxy(this.Oracle,[owner.address]);
    await oracle.waitForDeployment();
    let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target)
    console.log('Deployed: oracle     : ' + oracle.target)
    console.log('Imp                  : ' + oracleImplementation)
    //await hre.run("verify:verify", {address: oracle.target});

    let UPDATER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("UPDATER_ROLE"));

    console.log('oracle deploy at', oracle.target);

    let hasRole = await oracle.hasRole(UPDATER_ROLE, owner.address);
    console.log('DEPLOYER: %s has ADMIN_ROLE: %s', owner.address, hasRole);
    console.log('Finished');

}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
