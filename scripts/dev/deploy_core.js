const {
    REAL_ABNBC, ceBNBc, DEPLOYER
} = require('../../addresses.json');
const {ethers} = require("hardhat");


async function main() {
    console.log('Running deploy script');

    let collateral = ethers.encodeBytes32String("aBNBc");
    let collateral2 = ethers.encodeBytes32String("REALaBNBc");
    let collateral3 = ethers.encodeBytes32String("ceABNBc");

    this.Vat = await hre.ethers.getContractFactory("Vat");
    this.Spot = await hre.ethers.getContractFactory("Spotter");
    this.Usb = await hre.ethers.getContractFactory("Usb");
    this.ABNBC = await hre.ethers.getContractFactory("aBNBc");
    this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
    this.UsbJoin = await hre.ethers.getContractFactory("UsbJoin");
    // this.Oracle = await hre.ethers.getContractFactory("Oracle"); // Mock Oracle
    this.Jug = await hre.ethers.getContractFactory("Jug");
    this.Flop = await hre.ethers.getContractFactory("Flopper");
    this.Flap = await hre.ethers.getContractFactory("Flapper");
    this.Vow = await hre.ethers.getContractFactory("Vow");
    this.Jar = await hre.ethers.getContractFactory("Jar");
    this.Dog = await hre.ethers.getContractFactory("Dog");
    this.Clip = await hre.ethers.getContractFactory("Clipper");

    const vat = await this.Vat.deploy();
    await vat.waitForDeployment();
    console.log("Vat deployed to:", vat.target);

    const spot = await this.Spot.deploy(vat.target);
    await spot.waitForDeployment();
    console.log("Spot deployed to:", spot.target);

    const abnbc = await this.ABNBC.deploy("Stage aBNBc", "stgABNBc");
    await abnbc.waitForDeployment();
    console.log("aBNBc deployed to:", abnbc.target);

    const usb = await this.Usb.deploy(97, "stgUSB");
    await usb.waitForDeployment();
    console.log("Usb deployed to:", usb.target);

    const usbJoin = await this.UsbJoin.deploy(vat.target, usb.target);
    await usbJoin.waitForDeployment();
    console.log("usbJoin deployed to:", usbJoin.target);
    //
    const abnbcJoin = await this.GemJoin.deploy(vat.target, collateral, abnbc.target);
    await abnbcJoin.waitForDeployment();
    console.log("abnbcJoin deployed to:", abnbcJoin.target);

    const abnbcJoin2 = await this.GemJoin.deploy(vat.target, collateral2, REAL_ABNBC);
    await abnbcJoin2.waitForDeployment();
    console.log("abnbcJoin2 deployed to:", abnbcJoin2.target);

    const bnbJoin = await this.GemJoin.deploy(vat.target, collateral3, ceBNBc);
    await bnbJoin.waitForDeployment();
    console.log("bnbJoin deployed to:", bnbJoin.target);

    // const oracle = await this.Oracle.deploy();
    // await oracle.waitForDeployment();
    // console.log("Oracle deployed to:", oracle.target);
    // const oracle2 = await this.Oracle.deploy();
    // await oracle2.waitForDeployment();
    // console.log("Oracle2 deployed to:", oracle2.target);

    jug = await this.Jug.deploy(vat.target);
    await jug.waitForDeployment();
    console.log("Jug deployed to:", jug.target);

    const flop = await this.Flop.deploy(vat.target, usbJoin.target);
    await flop.waitForDeployment();
    console.log("Flop deployed to:", flop.target);

    const flap = await this.Flap.deploy(vat.target, usbJoin.target);
    await flap.waitForDeployment();
    console.log("Flap deployed to:", flap.target);

    const vow = await this.Vow.deploy(vat.target, flap.target, flop.target, DEPLOYER);
    await vow.waitForDeployment();
    console.log("Vow deployed to:", vow.target);

    const dog = await this.Dog.deploy(vat.target);
    await dog.waitForDeployment();
    console.log("Dog deployed to:", dog.target);

    const jar = await this.Jar.deploy("Helio Earn", "EARN");
    await jar.waitForDeployment();
    console.log("Jar deployed to:", jar.target);

    const clip1 = await this.Clip.deploy(vat.target, spot.target, dog.target, collateral);
    await clip1.waitForDeployment();
    console.log("Clip1 deployed to:", clip1.target);
    const clip2 = await this.Clip.deploy(vat.target, spot.target, dog.target, collateral2);
    await clip2.waitForDeployment();
    console.log("Clip2 deployed to:", clip2.target);
    const clip3 = await this.Clip.deploy(vat.target, spot.target, dog.target, collateral3);
    await clip3.waitForDeployment();
    console.log("Clip3 deployed to:", clip3.target);

    console.log('Validating code');
    await hre.run("verify:verify", {
        address: vat.target
    });

    await hre.run("verify:verify", {
        address: usb.target,
        constructorArguments: [
            97,
            "stgUSB"
        ],
    });

    await hre.run("verify:verify", {
        address: abnbc.target,
        constructorArguments: [
            "Stage aBNBc",
            "stgABNBc",
        ],
    });

    // await hre.run("verify:verify", {
    //     address: oracle.target,
    // });
    // await hre.run("verify:verify", {
    //     address: oracle2.target,
    // });

    await hre.run("verify:verify", {
        address: spot.target,
        constructorArguments: [
            vat.target
        ],
    });

    await hre.run("verify:verify", {
        address: usbJoin.target,
        constructorArguments: [
            vat.target,
            usb.target,
        ],
    });
    await hre.run("verify:verify", {
        address: abnbcJoin.target,
        constructorArguments: [
            vat.target,
            collateral,
            abnbc.target,
        ],
    });
    await hre.run("verify:verify", {
        address: abnbcJoin2.target,
        constructorArguments: [
            vat.target,
            collateral2,
            REAL_ABNBC
        ],
    });
    await hre.run("verify:verify", {
        address: bnbJoin.target,
        constructorArguments: [
            vat.target,
            collateral3,
            ceBNBc,
        ],
    });

    await hre.run("verify:verify", {
        address: jug.target,
        constructorArguments: [
            vat.target
        ],
    });
    await hre.run("verify:verify", {
        address: flop.target,
        constructorArguments: [
            vat.target,
            usbJoin.target,
        ],
    });
    await hre.run("verify:verify", {
        address: flap.target,
        constructorArguments: [
            vat.target,
            usbJoin.target,
        ],
    });
    await hre.run("verify:verify", {
        address: vow.target,
        constructorArguments: [
            vat.target,
            flap.target,
            flop.target,
            DEPLOYER
        ],
    });
    await hre.run("verify:verify", {
        address: jar.target,
        constructorArguments: [
            "Helio Earn",
            "EARN"
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


// Vat deployed to: 0x9f581c6ba30CD71EFC636E9F24E1692fa912036c
// Spot deployed to: 0x409796868312c7538d962c88A5f8204f78AE765d
// aBNBc deployed to: 0x977CC8148260284B3F8f4D6585910622f579a708
// Usb deployed to: 0xB5e96829A42AB622C56C1Ab9a0572CbfbED4aa27
// usbJoin deployed to: 0x0c53fdd1649a1A8Ccf4D0767569bFB257Ecef85B
// abnbcJoin deployed to: 0xbf64ff5e927709A03aad20467E6705d25e358F81
// abnbcJoin2 deployed to: 0x22343a201EAA818c2F7F50522af3AE29480919a1
// bnbJoin deployed to: 0x8E977c87F7060B0Ca2dc87fA47BF24389A78145f
// Jug deployed to: 0x719c69E6FF37318789223f9D05e318075986EA42
// Flop deployed to: 0x4B92743bcEebC768f9dcE571A3B20a5Ea5f47630
// Flap deployed to: 0x60030415e2F0De997f7F285707fA4d3379a5DcB4
