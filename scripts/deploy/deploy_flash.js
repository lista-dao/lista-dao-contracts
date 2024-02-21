const {ethers, upgrades} = require("hardhat");

const auctionProxy = "0x2cf64bCB720b91373Df1315ED15188FF5D8C06Ab"; // Interaction
const dex = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3";
const vat = "0xaAe55ecf3D89a129F2039628b3D2A575cD8D9863";
const hay = "0x7adC9A28Fab850586dB99E7234EA2Eb7014950fA";
const hayJoin = "0x3F9Af26DDBeBb677EA668d8dC5986545230A6b3D";
const vow = "0xD5b2B20955a99259993b4DC73C0120E70c192089";

async function main() {
    this.Flash = await ethers.getContractFactory("Flash");
    const flash = await upgrades.deployProxy(this.Flash, [vat, hay, hayJoin, vow]);
    await flash.waitForDeployment();
    let flashImplementation = await upgrades.erc1967.getImplementationAddress(flash.target);
    console.log("Deployed: Flash    : " + flash.target);
    console.log("Imp                  : " + flashImplementation);


    const flashBuy = await ethers.deployContract("FlashBuy", [flash.target, auctionProxy, dex]);
    await flashBuy.waitForDeployment();
    console.log("Deployed: FlashBuy    : " + flashBuy.target);

    await hre.run("verify:verify", {address: flashImplementation, constructorArguments: []});
    await hre.run("verify:verify", {address: flashBuy, constructorArguments: [flash.target, auctionProxy, dex]});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

