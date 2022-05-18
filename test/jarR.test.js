const { expect } = require('chai');
const { BigNumber } = require('ethers');
const { joinSignature } = require('ethers/lib/utils');
const { ethers, network } = require('hardhat');
const Web3 = require('web3');

const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

const DATA = "0x02";

xdescribe('===Jar===', function () {
    let deployer, signer1, signer2, signer3, multisig;

    let vat, 
        spot, 
        abnbc,
        gemJoin, 
        jug,
        vow,
        jar;

    let oracle;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000", // 45 Decimals
        ONE = 10 ** 27;


    let collateral = ethers.utils.formatBytes32String("aBNBc");

    beforeEach(async function () {

        ////////////////////////////////
        /** Deployments ------------ **/
        ////////////////////////////////

        [deployer, signer1, signer2, signer3, multisig] = await ethers.getSigners();

        this.Vat = await ethers.getContractFactory("Vat");
        this.Spot = await ethers.getContractFactory("Spotter");
        this.GemJoin = await ethers.getContractFactory("GemJoin");
        this.UsbJoin = await ethers.getContractFactory("UsbJoin");
        this.Usb = await ethers.getContractFactory("Usb");
        this.Jug = await ethers.getContractFactory("Jug");
        this.Vow = await ethers.getContractFactory("Vow");
        this.Jar = await ethers.getContractFactory("JarR");
        this.Oracle = await ethers.getContractFactory("Oracle"); // Mock Oracle

        // Core module
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        spot = await this.Spot.connect(deployer).deploy(vat.address);
        await spot.deployed();

        // Collateral module
        abnbc = await this.Usb.connect(deployer).deploy(97);
        await abnbc.deployed(); // Collateral
        gemJoin = await this.GemJoin.connect(deployer).deploy(vat.address, collateral, abnbc.address);
        await gemJoin.deployed();

        // Usb module
        usb = await this.Usb.connect(deployer).deploy(97);
        await usb.deployed(); // Stable Coin
        usbJoin = await this.UsbJoin.connect(deployer).deploy(vat.address, usb.address);
        await usbJoin.deployed();

        // Rates module
        jug = await this.Jug.connect(deployer).deploy(vat.address);
        await jug.deployed();

        // System Stabilizer module (balance sheet)
        vow = await this.Vow.connect(deployer).deploy(vat.address, NULL_ADDRESS, NULL_ADDRESS, multisig.address);
        await vow.deployed();

        // Jar module 
        jar = await this.Jar.connect(deployer).deploy(usb.address, "Helio USB", "hUSB");
        await jar.deployed();

        // Oracle module
        oracle = await this.Oracle.connect(deployer).deploy();
        await oracle.deployed();

        //////////////////////////////
        /** Initial Setup -------- **/
        //////////////////////////////

        // Initialize Oracle Module
        // 2.000000000000000000000000000 ($) * 0.8 (80%) = 1.600000000000000000000000000, 
        // 2.000000000000000000000000000 / 1.600000000000000000000000000 = 1.250000000000000000000000000 = mat
        await oracle.connect(deployer).setPrice("2" + wad); // 2$, mat = 80%, 2$ * 80% = 1.6$ With Safety Margin

        // Initialize Core Module 
        await vat.connect(deployer).init(collateral);
        await vat.connect(deployer).rely(gemJoin.address);
        await vat.connect(deployer).rely(spot.address);
        await vat.connect(deployer).rely(jug.address);
        await vat.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "5000" + rad); // Normalized USB
        await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("line"), "5000" + rad); // Normalized USB

        await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), oracle.address);
        await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio
        await spot.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // It means pegged to 1$
        await spot.connect(deployer).poke(collateral);

        // Initialize Collateral Module [User should approve gemJoin while joining]

        // Initialize Usb Module
        await usb.connect(deployer).rely(usbJoin.address);

        // Initialize Rates Module
        await jug.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), "1000000000315529215730000000"); // 1% Yearly
        // evm does not support stopping time for now == rho, so we create a mock contract which calls both functions to set duty
        let proxyLike = await (await (await ethers.getContractFactory("ProxyLike")).connect(deployer).deploy(jug.address, vat.address)).deployed();
        await jug.connect(deployer).rely(proxyLike.address);
        await proxyLike.connect(deployer).jugInitFile(collateral, ethers.utils.formatBytes32String("duty"), "0000000000312410000000000000"); // 1% Yearly Factored
        await jug.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);

        // Signer1, Signer2 and Signer3 have some aBNBc
        await abnbc.connect(deployer).mint(signer1.address, ethers.utils.parseEther("5000"));
        await abnbc.connect(deployer).mint(signer2.address, ethers.utils.parseEther("5000"));
        await abnbc.connect(deployer).mint(signer3.address, ethers.utils.parseEther("5000"));

        // Signer1, Signer2 and Signer3 entered the system with 1000, 2000, and 3000 respectively (Unlocked)
        await abnbc.connect(signer1).approve(gemJoin.address, ethers.utils.parseEther("1000"));
        await gemJoin.connect(signer1).join(signer1.address, ethers.utils.parseEther("1000"));
        await abnbc.connect(signer2).approve(gemJoin.address, ethers.utils.parseEther("2000"));
        await gemJoin.connect(signer2).join(signer2.address, ethers.utils.parseEther("2000"));
        await abnbc.connect(signer3).approve(gemJoin.address, ethers.utils.parseEther("3000"));
        await gemJoin.connect(signer3).join(signer3.address, ethers.utils.parseEther("3000"));
        
        // Signer1, Signer2 and Signer3 collateralize 500, 1000 and 1500 respectively
        await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, ethers.utils.parseEther("500"), 0); // 500 * 1.6$ = 800$ worth locked
        await vat.connect(signer2).frob(collateral, signer2.address, signer2.address, signer2.address, ethers.utils.parseEther("1000"), 0); // 1000 * 1.6$ = 1600$ worth locked
        await vat.connect(signer3).frob(collateral, signer3.address, signer3.address, signer3.address, ethers.utils.parseEther("1500"), 0); // 1500 * 1.6$ = 2400$ worth locked

        // // Signer1, Signer2 and Signer2 borrow Usb respectively
        let debt_rate = await (await vat.ilks(collateral)).rate;
        let usb_amount1 = (400000000000000000000 / debt_rate) * ONE;
        let usb_amount2 = (800000000000000000000 / debt_rate) * ONE;
        let usb_amount3 = "1200000000000000000000";
    
        await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, usb_amount1.toString()); // 400 USBs
        await vat.connect(signer2).frob(collateral, signer2.address, signer2.address, signer2.address, 0, usb_amount2.toString()); // 800 USBs
        await vat.connect(signer3).frob(collateral, signer3.address, signer3.address, signer3.address, 0, usb_amount3); // 1200 USBs
        await network.provider.send("evm_mine");
        await network.provider.send("evm_setAutomine", [false]);
        // await network.provider.send("evm_setNextBlockTimestamp", ["TIME"]) 
        // await hre.ethers.provider.send('evm_increaseTime', [7 * 24 * 60 * 60]);

        await network.provider.send("evm_mine")
        debt_rate = await (await vat.ilks(collateral)).rate;
        // console.log("ILK_RATE      : " + debt_rate.toString());
        // console.log("Usb(signer1)  : " + await (await vat.connect(signer1).usb(signer3.address)).toString());
        // console.log("Debt          : " + await (await vat.connect(signer1).debt()).toString());

        // Update Stability Fees
        await network.provider.send("evm_increaseTime", [157680000]); // Jump 5 Year
        await jug.connect(deployer).drip(collateral);
        await network.provider.send("evm_mine");
        
        debt_rate = await (await vat.ilks(collateral)).rate;
        // console.log("---After One Year");
        // console.log("ILK_RATE      : " + debt_rate.toString());
        // console.log("Debt          : " + await (await vat.connect(signer1).debt()).toString());
        // let usbWithStabilityFee = (debt_rate * await (await vat.connect(signer1).urns(collateral, signer1.address)).art) / ONE; // rate * art = usb 
        // let stabilityFee = (usbWithStabilityFee - (await vat.connect(signer1).usb(signer1.address) / ONE)); // S.fee = usbWithStabilityFee - usb
        // console.log("S.Fee(signer1): " + stabilityFee + " in USB (2% After 5 Years)");

        // Vat has surplus amount of about 249 USBs now because stability fees
        await network.provider.send("evm_setAutomine", [true]);
    });

    describe('---join ---exit', function () {
        it('Case', async function () {

            // await network.provider.send("evm_setAutomine", [false]);
            let tau;

            {
                tau = (await ethers.provider.getBlock()).timestamp;
                await network.provider.send("evm_setNextBlockTimestamp", [tau + 1]);
                await network.provider.send("evm_mine");
                // console.log((await ethers.provider.getBlock()).timestamp)
            }

            {
                tau = (await ethers.provider.getBlock()).timestamp;
                await network.provider.send("evm_setNextBlockTimestamp", [tau + 1]);
                
                await vow.connect(deployer).flap();
                await vat.connect(multisig).hope(usbJoin.address)
                await usbJoin.connect(multisig).exit(multisig.address, "100" + wad)
                await usb.connect(multisig).approve(jar.address, "10" + wad)
                await jar.connect(multisig).replenish("10" + wad);

                vat.connect(signer1).hope(usbJoin.address);
                await usbJoin.connect(signer1).exit(signer1.address, "50" + wad);
                await usb.connect(signer1).approve(jar.address, "50" + wad);
                await jar.connect(signer1).join("50" + wad);

                await network.provider.send("evm_mine"); // 0th

                tau = (await ethers.provider.getBlock()).timestamp;
                await network.provider.send("evm_setNextBlockTimestamp", [tau + 5]);

                vat.connect(signer2).hope(usbJoin.address);
                await usbJoin.connect(signer2).exit(signer2.address, "100" + wad);
                await usb.connect(signer2).approve(jar.address, "100" + wad);
                await jar.connect(signer2).join("100" + wad);

                await network.provider.send("evm_mine"); // 5th

                expect(await jar.balanceOf(signer1.address)).to.equal("50" + wad);
                expect(await jar.balanceOf(signer2.address)).to.equal("100" + wad);

                tau = (await ethers.provider.getBlock()).timestamp;
                await network.provider.send("evm_setNextBlockTimestamp", [tau + 10]);
                                
                await usb.connect(multisig).approve(jar.address, "10" + wad)
                await jar.connect(multisig).replenish("10" + wad);

                await network.provider.send("evm_mine"); // 0th
                console.log(await jar.redeemables(signer1.address))

                expect(await jar.balanceOf(signer1.address)).to.equal("50" + wad);
                expect(await jar.balanceOf(signer2.address)).to.equal("100" + wad);
                expect(await jar.ratio()).to.equal("937500000000000000");

                tau = (await ethers.provider.getBlock()).timestamp;
                await network.provider.send("evm_setNextBlockTimestamp", [tau + 10]);
                                
                await jar.connect(signer1).exit("50" + wad);

                await network.provider.send("evm_mine");
                console.log(await jar.redeemables(signer1.address))

                tau = (await ethers.provider.getBlock()).timestamp;
                await network.provider.send("evm_setNextBlockTimestamp", [tau + 10]);
                                
                await usb.connect(multisig).approve(jar.address, "10" + wad)
                await jar.connect(multisig).replenish("10" + wad);
                await jar.connect(signer2).exit("100" + wad);

                await network.provider.send("evm_mine"); // 10th
            }
        });
    })
});