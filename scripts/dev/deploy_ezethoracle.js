const {ethers, upgrades} = require('hardhat');

async function main() {
    console.log('Running deploy script');

    let collateral = ethers.encodeBytes32String('EZETH');
    //ETHUSD
    let ethUsdPriceFeed = '0xc0e60De0CB09a432104C823D3150dDEEA90E8f7d'

    //EzethEth
    let ezEthEthPriceFeed = '0x77D231e51614C84e15CCC38E2a52BFab49D6853C'
    let SPOT = '0x15493D9141481505f7CA3e591Cea2cBB03637B1d'

    let proxyAddress = '0xeCf92977F937eAECf9F2124c4E3361d248A2988C';


    const Oracle = await ethers.getContractFactory("EzethOracle");
    const newImplAddress = await upgrades.prepareUpgrade(proxyAddress, Oracle);

    console.log("新的合约实现已经部署在地址:", newImplAddress);



    // 3. 更新代理使用新的合约实现
    const upgradedOracle = await upgrades.upgradeProxy(proxyAddress, Oracle);
    console.log("代理现在正在使用新的合约实现:", upgradedOracle.address);






    this.Oracle = await hre.ethers.getContractFactory('EzethOracle')

    const oracle = await upgrades.deployProxy(this.Oracle, [priceFeed])
    await oracle.waitForDeployment()
    let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target)
    console.log('Deployed: oracle     : ' + oracle.target)
    console.log('Imp                  : ' + oracleImplementation)

   // let oracleAddr = oracle.target;

/*
    this.Spot = await hre.ethers.getContractFactory("Spotter");

    const spot = await this.Spot.attach(SPOT);
    await spot["file(bytes32,bytes32,address)"](collateral, ethers.encodeBytes32String("pip"), oracle.target);
    //await spot.poke(collateral);
    console.log('set spot');
*/


    await hre.run('verify:verify', {address: oracle.target})
    await hre.run('verify:verify', {address: oracleImplementation, contract: 'contracts/oracle/EzethOracle.sol:EzethOracle'})

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
