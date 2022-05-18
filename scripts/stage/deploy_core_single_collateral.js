const hre = require("hardhat");

const {
    USB, ceBNBc, DEPLOYER, COLLATERAL_CE_ABNBC
} = require('../../addresses-stage.json');
const {ethers} = require("hardhat");


async function main() {
    console.log('Running deploy script');

    let collateral3 = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    // this.Usb = await hre.ethers.getContractFactory("Usb");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.UsbJoin = await hre.ethers.getContractFactory("UsbJoin");
    // this.Oracle = await hre.ethers.getContractFactory("Oracle"); // Mock Oracle
    this.Jug = await hre.ethers.getContractFactory("Jug");
    this.Flop = await hre.ethers.getContractFactory("Flopper");
    this.Flap = await hre.ethers.getContractFactory("Flapper");
    this.Vow = await hre.ethers.getContractFactory("Vow");
    // this.Jar = await hre.ethers.getContractFactory("Jar");
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Clip = await hre.ethers.getContractFactory("Clipper");

    const vat = await this.Vat.deploy();
    await vat.deployed();
    console.log("Vat deployed to:", vat.address);

    const spot = await this.Spot.deploy(vat.address);
    await spot.deployed();
    console.log("Spot deployed to:", spot.address);

    // const usb = await this.Usb.deploy(97, "stgUSB");
    // await usb.deployed();
    // console.log("Usb deployed to:", usb.address);

    const usbJoin = await this.UsbJoin.deploy(vat.address, USB);
    await usbJoin.deployed();
    console.log("usbJoin deployed to:", usbJoin.address);

    const bnbJoin = await this.GemJoin.deploy(vat.address, collateral3, ceBNBc);
    await bnbJoin.deployed();
    console.log("bnbJoin deployed to:", bnbJoin.address);

    jug = await this.Jug.deploy(vat.address);
    await jug.deployed();
    console.log("Jug deployed to:", jug.address);

    const flop = await this.Flop.deploy(vat.address, usbJoin.address);
    await flop.deployed();
    console.log("Flop deployed to:", flop.address);

    const flap = await this.Flap.deploy(vat.address, usbJoin.address);
    await flap.deployed();
    console.log("Flap deployed to:", flap.address);

    const vow = await this.Vow.deploy(vat.address, flap.address, flop.address, DEPLOYER);
    await vow.deployed();
    console.log("Vow deployed to:", vow.address);

    const dog = await this.Dog.deploy(vat.address);
    await dog.deployed();
    console.log("Dog deployed to:", dog.address);

    const clip3 = await this.Clip.deploy(vat.address, spot.address, dog.address, collateral3);
    await clip3.deployed();
    console.log("Clip3 deployed to:", clip3.address);

    console.log('Validating code');
    await hre.run("verify:verify", {
        address: vat.address
    });

    await hre.run("verify:verify", {
        address: spot.address,
        constructorArguments: [
            vat.address
        ],
    });

    await hre.run("verify:verify", {
        address: usbJoin.address,
        constructorArguments: [
            vat.address,
            USB,
        ],
    });

    await hre.run("verify:verify", {
        address: bnbJoin.address,
        constructorArguments: [
            vat.address,
            collateral3,
            ceBNBc,
        ],
    });

    await hre.run("verify:verify", {
        address: jug.address,
        constructorArguments: [
            vat.address
        ],
    });
    await hre.run("verify:verify", {
        address: flop.address,
        constructorArguments: [
            vat.address,
            usbJoin.address,
        ],
    });
    await hre.run("verify:verify", {
        address: flap.address,
        constructorArguments: [
            vat.address,
            usbJoin.address,
        ],
    });
    await hre.run("verify:verify", {
        address: vow.address,
        constructorArguments: [
            vat.address,
            flap.address,
            flop.address,
            DEPLOYER
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


// Vat deployed to: 0x4281F2358582d1C2822092925DeE4653aE51a8DB
// Spot deployed to: 0xc13252E0D297e66b1950fc171b216bF44D171044
// usbJoin deployed to: 0x35AABb48D681093Bc5Df10379479Da43E38Bd213
// bnbJoin deployed to: 0x327AC7593e3ec67795FECf6CE8165F8bC6483A9C
// Jug deployed to: 0x4D8b2A8421E1A9a36a666F89b8d618D94af16Cd1
// Flop deployed to: 0x29F8353865e9993C2A8bBF56c96105D83A6d5b84
// Flap deployed to: 0x18b362539C18f47B59F6e8572F8915Ef22c2f238
// Vow deployed to: 0xf09AD55a44cAE1d83a0f023033A947a85EFF49FB
// Duplicate definition of File (File(bytes32,uint256), File(bytes32,address), File(bytes32,bytes32,uint256), File(bytes32,bytes32,address))
// Dog deployed to: 0xaa544A848E4AFFda9b0073042FadD9000e760340
// Duplicate definition of File (File(bytes32,uint256), File(bytes32,address))
// Clip3 deployed to: 0xB61b68cd56d83ac79d171D5CF8CF7a1a29715195