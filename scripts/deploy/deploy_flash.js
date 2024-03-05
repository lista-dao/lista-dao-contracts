const {ethers, upgrades} = require("hardhat");

const auctionProxy = "0xb7A5999AEaE17C37d07ac4b34e56757c96387c84"; // address of Interaction
const dex = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3";
const vat = "0xC9eeBDB18bD05dCF981F340b838E8CdD946D60ad";
const hay = "0x89b56C1997cefC6415A140e41A00Ad03dCac3ed0";
const hayJoin = "0xA9B7FC4F0ab06b94eC827dfB380e1B9B003cb930";
const vow = "0x08b0e59E3AC9266738c6d14bAbAA414f3A989ccc";

async function main() {
    this.Flash = await ethers.getContractFactory("Flash");
    const flash = await upgrades.deployProxy(this.Flash, [vat, hay, hayJoin, vow]);
    await flash.waitForDeployment();
    let flashImplementation = await upgrades.erc1967.getImplementationAddress(flash.target);
    console.log("Deployed: Flash    : " + flash.target);
    console.log("Imp                  : " + flashImplementation);

    this.FlashBuy = await ethers.getContractFactory("FlashBuy");
    const flashBuy = await upgrades.deployProxy(this.FlashBuy, [flash.target, auctionProxy, dex]);
    await flashBuy.waitForDeployment();
    let flashBuyImplementation = await upgrades.erc1967.getImplementationAddress(flashBuy.target);
    console.log("Deployed: FlashBuy    : " + flashBuy.target);
    console.log("Imp                  : " + flashBuyImplementation);

    await hre.run("verify:verify", {address: flash}, [vat, hay, hayJoin, vow]);
    await hre.run("verify:verify", {address: flashBuy}, [flash, auctionProxy, dex]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

