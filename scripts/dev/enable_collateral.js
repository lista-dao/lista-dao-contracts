const { VAT,
    SPOT,
    aBNBc,
    USB,
    UsbJoin,
    aBNBcJoin,
    Oracle,
    JUG,
    REAL_ABNBC,
    REALaBNBcJoin,
    INTERACTION} = require('../../addresses.json');
const {ethers} = require("hardhat");

async function main() {
    console.log('Running deploy script');

    let collateral = ethers.encodeBytes32String("aBNBc");
    let collateral2 = ethers.encodeBytes32String("REALaBNBc");

    this.Interaction = await hre.ethers.getContractFactory("Interaction");
    let interaction = this.Interaction.attach(INTERACTION);

    await interaction.enableCollateralType(aBNBc, aBNBcJoin, collateral);
    await interaction.enableCollateralType(REAL_ABNBC, REALaBNBcJoin, collateral2);

    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
