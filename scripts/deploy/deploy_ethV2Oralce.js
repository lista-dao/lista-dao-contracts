const hre = require('hardhat')
const {ethers, upgrades} = require('hardhat')
const {transferProxyAdminOwner} = require('../upgrades/utils/upgrade_utils')

async function main() {
    // check network and contract name
    console.log("Network : ", hre.network.name);
    [deployer] = await ethers.getSigners();
    let NEW_PROXY_ADMIN_OWNER = '0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253' // timelock

    const contractName = "ETHV2Oracle";
    const ETHV2Oracle = await ethers.getContractFactory(contractName);

    const oracle = await upgrades.deployProxy(ETHV2Oracle);
    await oracle.waitForDeployment();

    let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target)
    console.log('Deployed: oracle     : ' + oracle.target)
    console.log('Imp                  : ' + oracleImplementation)

    // transfer proxy admin ownership
    if (deployer.address !== NEW_PROXY_ADMIN_OWNER) {
        await transferProxyAdminOwner(oracle.target, NEW_PROXY_ADMIN_OWNER)
        console.log('Proxy Admin Ownership Of Oracle Transferred to: ' + NEW_PROXY_ADMIN_OWNER)
    }

    /**
     * Network:  bscLocal
     * Deployed: oracle     : 0x527BDf6848596a6470513219625d1a2F724bd311
     * Imp                  : 0xb1E850cC74e44df6b343324dA1B9DfA60b4033eA
     * Verifying implementation: 0xb1E850cC74e44df6b343324dA1B9DfA60b4033eA
     */
    // Verify
    await hre.run('verify:verify', {address: oracle.target})
    console.log('ETHV2Oracle verified successfully.');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

