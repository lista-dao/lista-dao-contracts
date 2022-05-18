const hre = require("hardhat");

const { JOIN } = require('../../addresses.json');

async function main() {
    console.log('Running deploy script');
    const mBNBFactory = await hre.ethers.getContractFactory("mBNB");
    const mbnb = await mBNBFactory.deploy(JOIN);
    await mbnb.deployed();
    console.log("mBNB deployed to:", mbnb.address);

    console.log('Validating code');
    await hre.run("verify:verify", {
        address: mbnb.address,
        constructorArguments: [
            JOIN
        ],
    });
    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
