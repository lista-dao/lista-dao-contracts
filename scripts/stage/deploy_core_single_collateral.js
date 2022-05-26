const hre = require("hardhat");

const {
    ceBNBc, DEPLOYER, COLLATERAL_CE_ABNBC
} = require('../../addresses-stage2.json');
const {ethers} = require("hardhat");


async function main() {
    console.log('Running deploy script');

    let collateral3 = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Usb = await hre.ethers.getContractFactory("Usb");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.UsbJoin = await hre.ethers.getContractFactory("UsbJoin");
    // this.Oracle = await hre.ethers.getContractFactory("Oracle"); // Mock Oracle
    this.Jug = await hre.ethers.getContractFactory("Jug");
    // this.Flop = await hre.ethers.getContractFactory("Flopper");
    // this.Flap = await hre.ethers.getContractFactory("Flapper");
    this.Vow = await hre.ethers.getContractFactory("Vow");
    // this.Jar = await hre.ethers.getContractFactory("Jar");
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Clip = await hre.ethers.getContractFactory("Clipper");
    this.Clip = await hre.ethers.getContractFactory("Clipper");

    const vat = await this.Vat.deploy();
    await vat.deployed();
    console.log("Vat deployed to:", vat.address);

    const spot = await this.Spot.deploy(vat.address);
    await spot.deployed();
    console.log("Spot deployed to:", spot.address);

    const usb = await this.Usb.deploy(97, "HAY");
    await usb.deployed();
    console.log("Usb deployed to:", usb.address);

    const usbJoin = await this.UsbJoin.deploy(vat.address, usb.address);
    await usbJoin.deployed();
    console.log("usbJoin deployed to:", usbJoin.address);

    const bnbJoin = await this.GemJoin.deploy(vat.address, collateral3, ceBNBc);
    await bnbJoin.deployed();
    console.log("bnbJoin deployed to:", bnbJoin.address);

    jug = await this.Jug.deploy(vat.address);
    await jug.deployed();
    console.log("Jug deployed to:", jug.address);

    // const flop = await this.Flop.deploy(vat.address, usbJoin.address);
    // await flop.deployed();
    // console.log("Flop deployed to:", flop.address);
    //
    // const flap = await this.Flap.deploy(vat.address, usbJoin.address);
    // await flap.deployed();
    // console.log("Flap deployed to:", flap.address);

    const vow = await this.Vow.deploy(vat.address, ethers.constants.AddressZero, ethers.constants.AddressZero, DEPLOYER);
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
            usb.address,
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
    // await hre.run("verify:verify", {
    //     address: flop.address,
    //     constructorArguments: [
    //         vat.address,
    //         usbJoin.address,
    //     ],
    // });
    // await hre.run("verify:verify", {
    //     address: flap.address,
    //     constructorArguments: [
    //         vat.address,
    //         usbJoin.address,
    //     ],
    // });
    await hre.run("verify:verify", {
        address: vow.address,
        constructorArguments: [
            vat.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
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