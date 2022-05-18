const { expect } = require('chai');
const { BigNumber } = require('ethers');
const { ethers, network } = require('hardhat');
const Web3 = require('web3');
const {ether} = require("@openzeppelin/test-helpers");

const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

const DATA = "0x02";

///////////////////////////////////////////
//Word of Notice: Commented means pending//
//The test will be updated on daily basis//
///////////////////////////////////////////

xdescribe('===MVP1===', function () {
    let deployer, signer1, signer2, signer3;

    let vat,
        spot,
        usb,
        abnbc,
        gemJoin,
        usbJoin,
        jug,
        dog,
        clipABNBC,
        abaci,
        vow,
        interaction,
        rewards,
        helio;

    let oracle;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000", // 45 Decimals
        ONE = 10 ** 27;


    let collateral = ethers.utils.formatBytes32String("aBNBc");
    let collateral2 = ethers.utils.formatBytes32String("aBNBc2");

    before(async function () {

        ////////////////////////////////
        /** Deployments ------------ **/
        ////////////////////////////////

        [deployer, signer1, signer2, signer3] = await ethers.getSigners();

        this.Vat = await ethers.getContractFactory("Vat");
        this.Spot = await ethers.getContractFactory("Spotter");
        this.Usb = await ethers.getContractFactory("Usb");
        this.GemJoin = await ethers.getContractFactory("GemJoin");
        this.UsbJoin = await ethers.getContractFactory("UsbJoin");
        this.Jug = await ethers.getContractFactory("Jug");
        this.Dog = await ethers.getContractFactory("Dog");
        this.ClipABNBC = await ethers.getContractFactory("Clipper");
        this.Abaci = await ethers.getContractFactory("LinearDecrease");
        this.Vow = await ethers.getContractFactory("Vow");
        this.Oracle = await ethers.getContractFactory("Oracle"); // Mock Oracle
        this.Interaction = await ethers.getContractFactory("DAOInteraction"); // Mock Oracle
        this.Rewards = await ethers.getContractFactory("HelioRewards");
        this.Helio = await ethers.getContractFactory("HelioToken");

        // Core module
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        spot = await this.Spot.connect(deployer).deploy(vat.address);
        await spot.deployed();

        // Usb module
        usb = await this.Usb.connect(deployer).deploy(97);
        await usb.deployed(); // Stable Coin
        usbJoin = await this.UsbJoin.connect(deployer).deploy(vat.address, usb.address);
        await usbJoin.deployed();

        // Collateral module
        abnbc = await this.Usb.connect(deployer).deploy(97);
        await abnbc.deployed(); // Collateral
        gemJoin = await this.GemJoin.connect(deployer).deploy(vat.address, collateral, abnbc.address);
        await gemJoin.deployed();

        // Rates module
        jug = await this.Jug.connect(deployer).deploy(vat.address);
        await jug.deployed();

        // Liquidation module
        dog = await this.Dog.connect(deployer).deploy(vat.address);
        await dog.deployed();
        clipABNBC = await this.ClipABNBC.connect(deployer).deploy(vat.address, spot.address, dog.address, collateral);
        await clipABNBC.deployed();
        abaci = await this.Abaci.connect(deployer).deploy();
        await abaci.deployed();

        // System Stabilizer module (balance sheet)
        vow = await this.Vow.connect(deployer).deploy(vat.address, NULL_ADDRESS, NULL_ADDRESS, NULL_ADDRESS);
        await vow.deployed();

        // Oracle module
        oracle = await this.Oracle.connect(deployer).deploy();
        await oracle.deployed();

        rewards = await this.Rewards.connect(deployer).deploy(vat.address);
        await rewards.deployed();
        helio = await this.Helio.connect(deployer).deploy();
        await helio.deployed();

        interaction = await this.Interaction.connect(deployer).deploy();
        await interaction.connect(deployer).initialize(
            vat.address,
            spot.address,
            usb.address,
            usbJoin.address,
            jug.address,
            dog.address,
            rewards.address,
        );

        await helio.connect(deployer).rely(rewards.address);
        await rewards.connect(deployer).setHelioToken(helio.address);
        await rewards.connect(deployer).initPool(collateral, "1000000001847694957439350500"); //6%
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
        await vat.connect(deployer).rely(usbJoin.address);
        await vat.connect(deployer).rely(spot.address);
        await vat.connect(deployer).rely(jug.address);
        await vat.connect(deployer).rely(dog.address);
        await vat.connect(deployer).rely(clipABNBC.address);
        await vat.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "20000" + rad); // Normalized USB
        await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("line"), "12000" + rad); // Normalized USB
        await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("dust"), "500" + rad); // Normalized USB

        await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), oracle.address);
        await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio
        await spot.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // It means pegged to 1$
        await spot.connect(deployer).poke(collateral);

        // Initialize Usb Module
        await usb.connect(deployer).rely(usbJoin.address);

        // Initialize Collateral Module [User should approve gemJoin while joining]

        // Initialize Rates Module
        // IMPORTANT: Base and Duty are added together first, thus will compound together.
        //            It is adviced to set a constant base first then duty for all ilks.
        //            Otherwise, a change in base rate will require a change in all ilks rate.
        //            Due to addition of both rates, the ratio should be adjusted by factoring.
        //            rate(Base) + rate(Duty) != rate(Base + Duty)

        // Calculating Base Rate (1% Yearly)
        // ==> principal*(rate**seconds)-principal = 0.01 (1%)
        // ==> 1 * (BR ** 31536000 seconds) - 1 = 0.01
        // ==> 1*(BR**31536000) = 1.01
        // ==> BR**31536000 = 1.01
        // ==> BR = 1.01**(1/31536000)
        // ==> BR = 1.000000000315529215730000000 [ray]
        // Factoring out Ilk Duty Rate (1% Yearly)
        // ((1 * (BR + 0.000000000312410000000000000 DR)^31536000)-1) * 100 = 0.000000000312410000000000000 = 2% (BR + DR Yearly)

        await jug.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), "1000000000315529215730000000"); // 1% Yearly
        // Setting duty requires now == rho. So Drip then Set, or Init then Set.
        // await jug.connect(deployer).init(collateral); // Duty by default set here to 1 Ray which is 0%, but added to Base that makes its effect compound
        // await jug.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("duty"), "0000000000312410000000000000"); // 1% Yearly Factored

        // evm does not support stopping time for now == rho, so we create a mock contract which calls both functions to set duty
        let proxyLike = await (await (await ethers.getContractFactory("ProxyLike")).connect(deployer).deploy(jug.address, vat.address)).deployed();
        await jug.connect(deployer).rely(proxyLike.address);
        await proxyLike.connect(deployer).jugInitFile(collateral, ethers.utils.formatBytes32String("duty"), "0000000000312410000000000000"); // 1% Yearly Factored

        expect(await(await jug.base()).toString()).to.be.equal("1000000000315529215730000000")
        expect(await(await(await jug.ilks(collateral)).duty).toString()).to.be.equal("312410000000000000");

        await jug.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);

        // Initialize Liquidation Module
        await dog.connect(deployer).rely(clipABNBC.address);
        await dog.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);
        await dog.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Hole"), "500" + rad);
        await dog.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("hole"), "250" + rad);
        await dog.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("chop"), "1100000000000000000"); // 10%
        await dog.connect(deployer)["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("clip"), clipABNBC.address);

        await clipABNBC.connect(deployer).rely(dog.address);
        await clipABNBC.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("buf"), "1100000000000000000000000000"); // 10%
        await clipABNBC.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tail"), "1800"); // 30mins reset time
        await clipABNBC.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
        await clipABNBC.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("chip"), "10000000000000000"); // 1% from vow incentive
        await clipABNBC.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
        await clipABNBC.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("stopped"), "0");
        await clipABNBC.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("spotter"), spot.address);
        await clipABNBC.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("dog"), dog.address);
        await clipABNBC.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);
        await clipABNBC.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("calc"), abaci.address);

        await abaci.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tau"), "3600"); // Price will reach 0 after this time

        // Initialize Stabilizer Module
        await vow.connect(deployer).rely(dog.address);

        await vat.connect(deployer).rely(interaction.address);
    });

    it('should check collateralization and borrowing Usb', async function () {

        // Signer1 and Signer2 have some aBNBc
        await abnbc.connect(deployer).mint(signer1.address, ethers.utils.parseEther("5000"));
        await abnbc.connect(deployer).mint(signer2.address, ethers.utils.parseEther("5000"));

        // Signer1 and Signer2 entered the system with 400 and 900 respectively (Unlocked)
        await abnbc.connect(signer1).approve(gemJoin.address, ethers.utils.parseEther("400"));
        await gemJoin.connect(signer1).join(signer1.address, ethers.utils.parseEther("400"));
        await abnbc.connect(signer2).approve(gemJoin.address, ethers.utils.parseEther("900"));
        await gemJoin.connect(signer2).join(signer2.address, ethers.utils.parseEther("900"));

        await network.provider.send("evm_mine");

        expect((await vat.connect(deployer).gem(collateral, signer1.address)).toString()).to.be.equal(await (ethers.utils.parseEther("400")).toString());
        expect((await vat.connect(deployer).gem(collateral, signer2.address)).toString()).to.be.equal(await (ethers.utils.parseEther("900")).toString());

        // Signer1 and Signer2 collateralize 400 and 900 respectively
        await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, ethers.utils.parseEther("400"), 0); // 400 * 1.6$ = 640$ worth locked
        await network.provider.send("evm_mine");
        expect((await vat.connect(deployer).gem(collateral, signer1.address)).toString()).to.be.equal(await (ethers.utils.parseEther("0")).toString());
        expect((await (await vat.connect(deployer).urns(collateral, signer1.address)).ink).toString()).to.be.equal(await (ethers.utils.parseEther("400")).toString());

        await vat.connect(signer2).frob(collateral, signer2.address, signer2.address, signer2.address, ethers.utils.parseEther("900"), 0); // 900 * 1.6$ = 1440$ worth locked
        await network.provider.send("evm_mine");
        expect((await vat.connect(deployer).gem(collateral, signer2.address)).toString()).to.be.equal(await (ethers.utils.parseEther("0")).toString());
        expect((await (await vat.connect(deployer).urns(collateral, signer2.address)).ink).toString()).to.be.equal(await (ethers.utils.parseEther("900")).toString());

        // Signer1 and Signer2 borrow Usb respectively [Note: Can be done in a single frob collateralize and borrow]
        // Note borrows should be less than "Line/line" and greater than "dust"
        // Note "dart" parameter in the frob is normalized. dart = Usb amount / ilk.rate
        expect((await vat.connect(signer1).usb(signer1.address)).toString()).to.be.equal("0");
        expect((await vat.connect(signer1).debt()).toString()).to.be.equal("0");
        expect((await (await vat.connect(signer1).urns(collateral, signer1.address)).art).toString()).to.be.equal("0");
        expect((await (await vat.connect(signer1).ilks(collateral)).Art).toString()).to.be.equal("0");

        // Normalized dart [wad] = amount in USB / ilk.rate
        let debt_rate = await (await vat.ilks(collateral)).rate;
        let usb_amount1 = (550000000000000000000 / debt_rate) * ONE;
        console.log("HERE")
        console.log(usb_amount1);
        let usb_amount2 = (600000000000000000000 / debt_rate) * ONE;

        await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, usb_amount1.toString()); // 550 USBs
        await vat.connect(signer2).frob(collateral, signer2.address, signer2.address, signer2.address, 0, usb_amount2.toString()); // 600 USBs
        await network.provider.send("evm_mine");

        debt_rate = await (await vat.ilks(collateral)).rate;
        console.log("ILK_RATE      : " + debt_rate.toString());
        console.log("ink(signer1)  : " + await (await vat.urns(collateral, signer1.address)).ink);
        console.log("art(signer1)  : " + await (await (await vat.connect(signer1).urns(collateral, signer1.address)).art).toString());
        console.log("Art           : " + await (await (await vat.connect(signer1).ilks(collateral)).Art).toString());
        console.log("Usb(signer1)  : " + await (await vat.connect(signer1).usb(signer1.address)).toString());
        console.log("Debt          : " + await (await vat.connect(signer1).debt()).toString());

        await interaction.connect(deployer).enableCollateralType(abnbc.address, gemJoin.address, collateral, clipABNBC.address);
        let borrowApr = await interaction.connect(deployer).borrowApr(abnbc.address);
        console.log("Interaction borrow apr: " + borrowApr.toString());
        let borrowed = await interaction.connect(signer1).borrowed(abnbc.address, signer1.address);
        expect(borrowed.toString()).to.be.equal("550000000000000070000");
        let distribution_rate = await rewards.connect(signer1).distributionApy();
        console.log("Distribution APY: " + distribution_rate.toString());
        // await interaction.setCollateralType(abnbc2.address, abnbcJoin2.address, collateral2, {from: deployer.address});

        // Update Stability Fees
        await network.provider.send("evm_increaseTime", [31536000]); // Jump 1 Year
        // await jug.connect(deployer).drip(collateral);
        await interaction.connect(deployer).drip(abnbc.address);
        await network.provider.send("evm_mine");

        borrowed = await interaction.connect(signer1).borrowed(abnbc.address, signer1.address);
        expect(borrowed.toString()).to.be.equal("561000048476391336205"); //+2%
        let unclaimed = await rewards.connect(signer1).pendingRewards(signer1.address);
        console.log("Unclaimed rewards: " + unclaimed.toString());
        await rewards.connect(signer1).claim(ether("10").toString());
        let helioBalance = await helio.connect(signer1).balanceOf(signer1.address);
        expect(helioBalance.toString()).to.equal(ether("10").toString());

        debt_rate = await (await vat.ilks(collateral)).rate;
        console.log("---After One Year");
        console.log("ILK_RATE      : " + debt_rate.toString());
        console.log("ink(signer1)  : " + await (await vat.urns(collateral, signer1.address)).ink);
        console.log("art(signer1)  : " + await (await (await vat.connect(signer1).urns(collateral, signer1.address)).art).toString());
        console.log("Art           : " + await (await (await vat.connect(signer1).ilks(collateral)).Art).toString());
        console.log("Usb(signer1)  : " + await (await vat.connect(signer1).usb(signer1.address)).toString());
        console.log("Debt          : " + await (await vat.connect(signer1).debt()).toString());
        let usbWithStabilityFee = (debt_rate * await (await vat.connect(signer1).urns(collateral, signer1.address)).art) / ONE; // rate * art = usb
        let stabilityFee = (usbWithStabilityFee - (await vat.connect(signer1).usb(signer1.address) / ONE)); // S.fee = usbWithStabilityFee - usb
        console.log("S.Fee(signer1): " + stabilityFee + "in USB (2% After One Year)");

         // Mint ERC20 Usb tokens based on internal Usb(signer1)
        await vat.connect(signer1).hope(usbJoin.address);
        expect((await usb.balanceOf(signer1.address)).toString()).to.equal("0");
        await usbJoin.connect(signer1).exit(signer1.address, ethers.utils.parseEther("300"));
        expect((await usb.balanceOf(signer1.address)).toString()).to.equal(ethers.utils.parseEther("300").toString());

        // Burn ERC20 Usb tokens to get internal Usb(signer1)
        await usb.connect(signer1).approve(usbJoin.address, ethers.utils.parseEther("300"))
        await usbJoin.connect(signer1).join(signer1.address, ethers.utils.parseEther("300"));
        expect((await usb.balanceOf(signer1.address)).toString()).to.equal("0");

        // Repaying all USB amount and closing the vault
        // Borrow the extra USB fee from market or Transfer from another vault
        await vat.connect(signer2).hope(usbJoin.address);
        await usbJoin.connect(signer2).exit(signer1.address, ethers.utils.parseEther("20"));
        await usb.connect(signer1).approve(usbJoin.address, ethers.utils.parseEther("20"))
        await usbJoin.connect(signer1).join(signer1.address, ethers.utils.parseEther("20"));
        usb_amount1 = -550000000000000070000
        await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, usb_amount1.toString()); // 550 USBs

        debt_rate = await (await vat.ilks(collateral)).rate;
        console.log("---After Repaying USB");
        console.log("ILK_RATE      : " + debt_rate.toString());
        console.log("ink(signer1)  : " + await (await vat.urns(collateral, signer1.address)).ink);
        console.log("art(signer1)  : " + await (await (await vat.connect(signer1).urns(collateral, signer1.address)).art).toString());
        console.log("Art           : " + await (await (await vat.connect(signer1).ilks(collateral)).Art).toString());
        console.log("Usb(signer1)  : " + await (await vat.connect(signer1).usb(signer1.address)).toString());
        console.log("Debt          : " + await (await vat.connect(signer1).debt()).toString());
        await network.provider.send("evm_mine");


        // Trying to liquidate Signer2 in an not-unsafe state
        await expect(dog.connect(deployer).bark(collateral, signer2.address, signer3.address)).to.be.revertedWith("Dog/not-unsafe");

        // Signer2 uncollaterlizes 517 abnbc
        await vat.connect(signer2).frob(collateral, signer2.address, signer2.address, signer2.address, "-517000000000000000000", 0);

        // After 1 year, Signer2's vault is unsafe
        // Update Stability Fees
        await network.provider.send("evm_increaseTime", [31536000]); // Jump 1 Year
        await jug.connect(deployer).drip(collateral);
        await network.provider.send("evm_mine");

        // Liquidator liquidates signer2
        await dog.connect(deployer).bark(collateral, signer2.address, signer3.address);

        // Signer2 Debt and Collateral after liquidation grab should be 0
        expect(await (await vat.urns(collateral, signer2.address)).ink).to.equal("0");
        expect(await (await (await vat.connect(signer2).urns(collateral, signer2.address)).art).toString()).to.equal("0");

        let sale = await clipABNBC.getStatus(1);
        console.log("---Before Auction Purchase")
        console.log(sale.lot);
        console.log(sale.tab);

        // Signer1 Buys 8 USB worth of Collateral
        await vat.connect(signer1).hope(clipABNBC.address);
        await clipABNBC.connect(signer1).take("1", "3" + wad, "2200000000000000000000000000", signer1.address, "0x");

        sale = await clipABNBC.getStatus(1);
        console.log("---After Auction Purchase")
        console.log(sale.lot);
        console.log(sale.tab);
    });

    it('Interaction test', async function () {

        await abnbc.connect(signer1).approve(interaction.address, ethers.utils.parseEther("100000"));
        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, ether("1200").toString());
        let locked = await interaction.connect(signer1).locked(abnbc.address, signer1.address);
        console.log("LOCKED: " + locked.toString())

        await usb.connect(signer1).approve(interaction.address, ethers.utils.parseEther("100000"));
        await interaction.connect(signer1).borrow(signer1.address, abnbc.address, ether("600").toString());
        let borrowed = await interaction.connect(signer1).borrowed(abnbc.address, signer1.address);
        console.log("Borrowed: " + borrowed.toString())

        await network.provider.send("evm_increaseTime", [31536000]); // Jump 1 Year
        await jug.connect(deployer).drip(collateral);
        await network.provider.send("evm_mine");

        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, ether("10").toString());
        await interaction.connect(signer1).borrow(signer1.address, abnbc.address, ether("600").toString());
        borrowed = await interaction.connect(signer1).borrowed(abnbc.address, signer1.address);
        console.log("Borrowed: " + borrowed.toString())
    });
});
