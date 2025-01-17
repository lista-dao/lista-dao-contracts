const hre = require("hardhat");

async function main() {
    console.log('Running deploy script');

    let MockMintable = await hre.ethers.getContractFactory("MockMintable");

    const name = 'mBTC'
    const symbol = 'mBTC'

    let mockMintable = await MockMintable.deploy(name, symbol)

    await mockMintable.waitForDeployment();
    const address = await mockMintable.getAddress();
    console.log("MockMintable deployed to:", address);

    console.log('Validating code');

    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: [
                name, symbol
            ]
        });
    } catch (error) {
        console.log('verify error:', error);
    }

    console.log('Finished');
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
