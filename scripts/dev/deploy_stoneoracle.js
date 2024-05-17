const {ethers, upgrades} = require('hardhat');

async function main() {
    console.log('Running deploy script');

    //let collateral = ethers.encodeBytes32String('EZETH');
    //ETHUSD
    let ethUsdPriceFeed = '0x635780E5D02Ab29d7aE14d266936A38d3D5B0CC5'

    //EzethEth-mock
    let stoneEthPriceFeed = '0x821929D88145823B6A6e81165845239C5A5a02Bf'
    let SPOT = '0x15493D9141481505f7CA3e591Cea2cBB03637B1d'

    const [deployer] = await ethers.getSigners();

    this.Oracle = await hre.ethers.getContractFactory('StoneOracleDev')

    const OracleSigner = Oracle.connect(deployer);

    const oracle = await upgrades.deployProxy(OracleSigner, [stoneEthPriceFeed, ethUsdPriceFeed]);
    await oracle.waitForDeployment()
    let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target)
    console.log('Deployed: oracle     : ' + oracle.target)
    console.log('Imp                  : ' + oracleImplementation)

   // let oracleAddr = oracle.target;

/*    this.Spot = await hre.ethers.getContractFactory("Spotter");

    const spot = await this.Spot.attach(SPOT);
    await spot["file(bytes32,bytes32,address)"](collateral, ethers.encodeBytes32String("pip"), oracle.target);
    //await spot.poke(collateral);
    console.log('set spot');*/


    await hre.run('verify:verify', {address: oracle.target})
    await hre.run('verify:verify', {address: oracleImplementation, contract: 'contracts/oracle/StoneOracleDev.sol:StoneOracleDev'})

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
