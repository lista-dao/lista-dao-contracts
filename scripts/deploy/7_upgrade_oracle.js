const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
require("@nomiclabs/hardhat-etherscan");

const oracleAddress = "0x346503c809A6cC88856CAC9602A643158cfeCD63";

const binanceDependencies = {
    chainlinkFeed: "0x2514895c72f50d8bd4b4f9b1110f0d6bd2c97526", //bnb
    binanceFeed: "0x1a26d803c2e796601794f8c5609549643832702c", // bnb
    pythContract: "0xd7308b14bf4008e7c7196ec35610b1427c5702ea",
    priceID: "0xecf553770d9b10965f8fb64771e93f5690a182edc32be4a3236e0caaa6e0581a", //bnb
    threshold: 120
};

const binanceTestDependencies = {
    chainlinkFeed: "0x2514895c72f50d8bd4b4f9b1110f0d6bd2c97526", //bnb
    binanceFeed: "0x1a26d803c2e796601794f8c5609549643832702c", //bnb
    pythContract: "0xd7308b14bf4008e7c7196ec35610b1427c5702ea",
    priceID: "0xecf553770d9b10965f8fb64771e93f5690a182edc32be4a3236e0caaa6e0581a", //bnb
    threshold: 120
};

async function main() {
    console.log('Running deploy script');

    const BnbOracle = await hre.ethers.getContractFactory("BnbOracleV2");

    console.log("Preparing upgrade...");
    const bnbOracleV2 = await upgrades.prepareUpgrade(oracleAddress, BnbOracle);
    console.log("bnbOracleV2 ", bnbOracleV2);
    const upgraded = await upgrades.upgradeProxy(oracleAddress, BnbOracle);
    console.log("bnbOracleV2 upgraded with ", upgraded.address);
    
    console.log("Upgrade states with one-time call function");
    if (hre.network.name == "bsc") {
        await (await upgraded.upgradeToV2(
            binanceDependencies.chainlinkFeed,
            binanceDependencies.binanceFeed,
            binanceDependencies.pythContract,
            binanceDependencies.priceID,
            binanceDependencies.threshold)).wait();
    } else {
        await (await upgraded.upgradeToV2(
            binanceTestDependencies.chainlinkFeed,
            binanceTestDependencies.binanceFeed,
            binanceTestDependencies.pythContract,
            binanceTestDependencies.priceID,
            binanceTestDependencies.threshold)).wait();
    }

    console.log('Validating code');
    await hre.run("verify:verify", {
        address: bnbOracleV2,
    });
    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
