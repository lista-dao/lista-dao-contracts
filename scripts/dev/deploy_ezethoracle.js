const {ethers, upgrades} = require('hardhat');

async function main() {
    console.log('Running deploy script');

    let collateral = ethers.encodeBytes32String('EZETH');
    //ETHUSD
    let ethUsdPriceFeed = '0xc0e60De0CB09a432104C823D3150dDEEA90E8f7d'

    //EzethEth-mock
    let ezEthEthPriceFeed = '0x77D231e51614C84e15CCC38E2a52BFab49D6853C'
    let SPOT = '0x15493D9141481505f7CA3e591Cea2cBB03637B1d'

    this.Oracle = await hre.ethers.getContractFactory('EzEthOracle')

    const oracle = await upgrades.deployProxy(this.Oracle, [ethUsdPriceFeed,ezEthEthPriceFeed])
    await oracle.waitForDeployment()
    let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target)
    console.log('Deployed: oracle     : ' + oracle.target)
    console.log('Imp                  : ' + oracleImplementation)

   // let oracleAddr = oracle.target;

    this.Spot = await hre.ethers.getContractFactory("Spotter");

    const spot = await this.Spot.attach(SPOT);
    await spot["file(bytes32,bytes32,address)"](collateral, ethers.encodeBytes32String("pip"), oracle.target);
    //await spot.poke(collateral);
    console.log('set spot');


    await hre.run('verify:verify', {address: oracle.target})
    await hre.run('verify:verify', {address: oracleImplementation, contract: 'contracts/oracle/EzEthOracle.sol:EzEthOracle'})

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
