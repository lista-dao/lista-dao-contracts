const {ethers, upgrades} = require("hardhat");

const interaction = "0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4"; // address of auction proxy
const flash = "0x64d94e715B6c03A5D8ebc6B2144fcef278EC6aAa"; // address of Flash
const dex = "0x10ED43C718714eb63d5aA57B78B54704E256024E"; // address of PancakeSwap

async function main() {
    this.FlashBuy = await ethers.getContractFactory("FlashBuy");
    const flashBuy = await upgrades.deployProxy(this.FlashBuy, [flash, interaction, dex]);
    await flashBuy.waitForDeployment();
    let flashBuyImplementation = await upgrades.erc1967.getImplementationAddress(flashBuy.target);
    console.log("Deployed: FlashBuy    : " + flashBuy.target);
    console.log("Imp                  : " + flashBuyImplementation);
    // await hre.run("verify:verify", {address: flashBuy}, [flash, interaction, dex]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

