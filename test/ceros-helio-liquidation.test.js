// THIS TEST FILE WAS WRITTEN WITH CEROS CONTRACTS
// IT CHECKS THE LIQUIDATION OF CEABNBC WHICH IS CONVERTED TO ABNBC
///////////////////////////////////////////////////////////////////




// const { expect } = require('chai');
// const { BigNumber } = require('ethers');
// const { ethers, network } = require('hardhat');
// const Web3 = require('web3');

// const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

// const DATA = "0x02";

// ///////////////////////////////////////////
// //Word of Notice: Commented means pending//
// //The test will be updated on daily basis//
// ///////////////////////////////////////////

// describe('===MVP1===', function () {
//     let deployer, signer1, signer2, signer3;

//     let vat, 
//         spot, 
//         usb, 
//         abnbc, 
//         gemJoinC,
//         usbJoin,
//         jug,
//         dog,
//         clipceaBNBc,
//         abaci,
//         vow,
//         dao,
//         cevault,
//         cetoken,
//         cerouter,
//         hBNB;

//     let oracle;

//     let wad = "000000000000000000", // 18 Decimals
//         ray = "000000000000000000000000000", // 27 Decimals
//         rad = "000000000000000000000000000000000000000000000", // 45 Decimals
//         ONE = 10 ** 27;


//     let collateral = ethers.utils.formatBytes32String("ceaBNBc");

//     before(async function () {

//         ////////////////////////////////
//         /** Deployments ------------ **/
//         ////////////////////////////////

//         [deployer, signer1, signer2, signer3] = await ethers.getSigners();

//         this.Vat = await ethers.getContractFactory("Vat");
//         this.Spot = await ethers.getContractFactory("Spotter");
//         this.Usb = await ethers.getContractFactory("Usb");
//         this.GemJoin = await ethers.getContractFactory("GemJoin");
//         this.UsbJoin = await ethers.getContractFactory("UsbJoin");
//         this.Jug = await ethers.getContractFactory("Jug");
//         this.Dog = await ethers.getContractFactory("Dog");
//         this.clipceaBNBc = await ethers.getContractFactory("Clipper");
//         this.Abaci = await ethers.getContractFactory("LinearDecrease");
//         this.Vow = await ethers.getContractFactory("Vow");
//         this.Oracle = await ethers.getContractFactory("Oracle"); // Mock Oracle
//         this.DAO = await ethers.getContractFactory("DAOInteraction");
//         this.CeVault = await ethers.getContractFactory("CeVault");
//         this.CeToken = await ethers.getContractFactory("CeToken");
//         this.CeRouter = await ethers.getContractFactory("CeRouter");
//         this.HBNB = await ethers.getContractFactory("hBNB");

//         // Core module
//         vat = await this.Vat.connect(deployer).deploy();
//         await vat.deployed();
//         spot = await this.Spot.connect(deployer).deploy(vat.address);
//         await spot.deployed();

//         // Usb module
//         usb = await this.Usb.connect(deployer).deploy(97);
//         await usb.deployed(); // Stable Coin
//         usbJoin = await this.UsbJoin.connect(deployer).deploy(vat.address, usb.address);
//         await usbJoin.deployed();

//         // Collateral module
//         abnbc = await this.Usb.connect(deployer).deploy(97);
//         await abnbc.deployed(); // Collateral
//         // gemJoin = await this.GemJoin.connect(deployer).deploy(vat.address, collateral, cetoken.address);
//         // await gemJoin.deployed();
        
//         // Rates module
//         jug = await this.Jug.connect(deployer).deploy(vat.address);
//         await jug.deployed();

//         // Liquidation module
//         dog = await this.Dog.connect(deployer).deploy(vat.address);
//         await dog.deployed();
//         clipceaBNBc = await this.clipceaBNBc.connect(deployer).deploy(vat.address, spot.address, dog.address, collateral);
//         await clipceaBNBc.deployed();
//         abaci = await this.Abaci.connect(deployer).deploy();
//         await abaci.deployed();

//         // System Stabilizer module (balance sheet)
//         vow = await this.Vow.connect(deployer).deploy(vat.address, NULL_ADDRESS, NULL_ADDRESS, NULL_ADDRESS);
//         await vow.deployed();

//         // Oracle module
//         oracle = await this.Oracle.connect(deployer).deploy();
//         await oracle.deployed();

//         //////////////////////////////
//         /** Initial Setup -------- **/
//         //////////////////////////////

//         // Initialize Oracle Module
//         // 2.000000000000000000000000000 ($) * 0.8 (80%) = 1.600000000000000000000000000, 
//         // 2.000000000000000000000000000 / 1.600000000000000000000000000 = 1.250000000000000000000000000 = mat
//         await oracle.connect(deployer).setPrice("2" + wad); // 2$, mat = 80%, 2$ * 80% = 1.6$ With Safety Margin

//         // Initialize Core Module 
//         await vat.connect(deployer).init(collateral);
//         await vat.connect(deployer).rely(usbJoin.address);
//         await vat.connect(deployer).rely(spot.address);
//         await vat.connect(deployer).rely(jug.address);
//         await vat.connect(deployer).rely(dog.address);
//         await vat.connect(deployer).rely(clipceaBNBc.address);
//         await vat.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "2000" + rad); // Normalized USB
//         await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("line"), "1200" + rad); // Normalized USB
//         await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("dust"), "500" + rad); // Normalized USB

//         await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), oracle.address);
//         await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio
//         await spot.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // It means pegged to 1$
//         await spot.connect(deployer).poke(collateral);

//         // Initialize Usb Module
//         await usb.connect(deployer).rely(usbJoin.address);

//         // Initialize Collateral Module [User should approve gemJoin while joining]

//         // Initialize Rates Module
//         // IMPORTANT: Base and Duty are added together first, thus will compound together.
//         //            It is adviced to set a constant base first then duty for all ilks.
//         //            Otherwise, a change in base rate will require a change in all ilks rate.
//         //            Due to addition of both rates, the ratio should be adjusted by factoring.
//         //            rate(Base) + rate(Duty) != rate(Base + Duty)

//         // Calculating Base Rate (1% Yearly)
//         // ==> principal*(rate**seconds)-principal = 0.01 (1%)
//         // ==> 1 * (BR ** 31536000 seconds) - 1 = 0.01
//         // ==> 1*(BR**31536000) = 1.01
//         // ==> BR**31536000 = 1.01
//         // ==> BR = 1.01**(1/31536000)
//         // ==> BR = 1.000000000315529215730000000 [ray]

//         // Factoring out Ilk Duty Rate (1% Yearly)
//         // ((1 * (BR + 0.000000000312410000000000000 DR)^31536000)-1) * 100 = 0.000000000312410000000000000 = 2% (BR + DR Yearly)

//         await jug.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), "1000000000315529215730000000"); // 1% Yearly
//         // Setting duty requires now == rho. So Drip then Set, or Init then Set.
//         // await jug.connect(deployer).init(collateral); // Duty by default set here to 1 Ray which is 0%, but added to Base that makes its effect compound
//         // await jug.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("duty"), "0000000000312410000000000000"); // 1% Yearly Factored

//         // evm does not support stopping time for now == rho, so we create a mock contract which calls both functions to set duty
//         let proxyLike = await (await (await ethers.getContractFactory("ProxyLike")).connect(deployer).deploy(jug.address, vat.address)).deployed();
//         await jug.connect(deployer).rely(proxyLike.address);
//         await proxyLike.connect(deployer).jugInitFile(collateral, ethers.utils.formatBytes32String("duty"), "0000000000312410000000000000"); // 1% Yearly Factored

//         expect(await(await jug.base()).toString()).to.be.equal("1000000000315529215730000000")
//         expect(await(await(await jug.ilks(collateral)).duty).toString()).to.be.equal("312410000000000000");

//         await jug.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);

//         // Initialize Liquidation Module
//         await dog.connect(deployer).rely(clipceaBNBc.address);
//         await dog.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);
//         await dog.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Hole"), "500" + rad);
//         await dog.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("hole"), "250" + rad);
//         await dog.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("chop"), "1100000000000000000"); // 10%
//         await dog.connect(deployer)["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("clip"), clipceaBNBc.address);

//         await clipceaBNBc.connect(deployer).rely(dog.address);
//         await clipceaBNBc.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("buf"), "1100000000000000000000000000"); // 10%
//         await clipceaBNBc.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tail"), "1800"); // 30mins reset time
//         await clipceaBNBc.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
//         await clipceaBNBc.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("chip"), "10000000000000000"); // 1% from vow incentive
//         await clipceaBNBc.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
//         await clipceaBNBc.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("stopped"), "0");
//         await clipceaBNBc.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("spotter"), spot.address);
//         await clipceaBNBc.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("dog"), dog.address);
//         await clipceaBNBc.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);
//         await clipceaBNBc.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("calc"), abaci.address);

//         await abaci.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tau"), "3600"); // Price will reach 0 after this time

//         // Initialize Stabilizer Module
//         await vow.connect(deployer).rely(dog.address);

//         // Initialize Interaction Module
//         dao = await this.DAO.connect(deployer).deploy();
//         dao.deployed();
//         await dao.connect(deployer).initialize(vat.address, spot.address, usb.address, usbJoin.address, jug.address, dog.address, NULL_ADDRESS);
//         vat.connect(deployer).rely(dao.address);

//         // Initialize CeVault and CeToken and CeRouter
//         cetoken = await this.CeToken.connect(deployer).deploy();
//         cevault = await this.CeVault.connect(deployer).deploy();
//         await cetoken.connect(deployer).initialize("Ceros aBNBc", "ceaBNBc");
//         await cevault.connect(deployer).initialize("Ceros Vault", cetoken.address, abnbc.address);
//         gemJoinC = await this.GemJoin.connect(deployer).deploy(vat.address, collateral, cetoken.address);
//         await gemJoinC.deployed();
//         await vat.connect(deployer).rely(gemJoinC.address);

//         await cetoken.connect(deployer).changeVault(cevault.address);

//         hBNB = await this.HBNB.connect(deployer).deploy();
//         await hBNB.deployed();
//         await hBNB.initialize();

//         cerouter = await this.CeRouter.connect(deployer).deploy();
//         await cerouter.deployed();
//         await hBNB.connect(deployer).changeMinter(cerouter.address);
//         await cerouter.connect(deployer).initialize(abnbc.address, NULL_ADDRESS, cetoken.address, NULL_ADDRESS, hBNB.address, cevault.address, dao.address, NULL_ADDRESS, NULL_ADDRESS);
//     });

//     it('should check collateralization and borrowing Usb', async function () {
        
//         // Signer1 and Signer2 have some aBNBc
//         await abnbc.connect(deployer).mint(signer1.address, ethers.utils.parseEther("5000"));
//         await abnbc.connect(deployer).mint(signer2.address, ethers.utils.parseEther("5000"));

//         // Enable collateral DAO
//         await dao.connect(deployer).enableCollateralType(cetoken.address, gemJoinC.address, collateral, clipceaBNBc.address);

//         // Deposit via CeRouter
//         await abnbc.connect(signer1).approve(cerouter.address,  ethers.utils.parseEther("400"))
//         await abnbc.connect(signer2).approve(cerouter.address,  ethers.utils.parseEther("900"))

//         await cerouter.connect(signer1).depositABNBc(ethers.utils.parseEther("400"));
//         await cerouter.connect(signer2).depositABNBc(ethers.utils.parseEther("900"));
                
//         // Normalized dart [wad] = amount in USB / ilk.rate
//         let debt_rate = await (await vat.ilks(collateral)).rate;
//         let usb_amount1 = (550000000000000000000 / debt_rate) * ONE;
//         // console.log("HERE")
//         // console.log(usb_amount1);
//         let usb_amount2 = (600000000000000000000 / debt_rate) * ONE;

//         await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, usb_amount1.toString()); // 550 USBs
//         await vat.connect(signer2).frob(collateral, signer2.address, signer2.address, signer2.address, 0, usb_amount2.toString()); // 600 USBs
//         await network.provider.send("evm_mine");

//         // // Trying to liquidate Signer2 in an not-unsafe state
//         // await expect(dog.connect(deployer).bark(collateral, signer2.address, signer3.address)).to.be.revertedWith("Dog/not-unsafe");

//         // Oracle price decreases
//         await oracle.connect(deployer).setPrice("600000000000000000");
//         await spot.connect(deployer).poke(collateral);

//         await dao.connect(signer3).startAuction(cetoken.address, signer2.address, signer3.address)

//         console.log("BEFORE-BUYING");
//         console.log("ceaBNBc: " + await cetoken.balanceOf(signer3.address));
//         console.log("aBNBc  : " + await abnbc.balanceOf(signer3.address));

//         await vat.connect(signer1).move(signer1.address, signer3.address, "50" + rad);
//         await vat.connect(signer3).hope(usbJoin.address);
//         await usbJoin.connect(signer3).exit(signer3.address, "50" + wad);

//         await dao.connect(deployer).setCollateralDisc(cetoken.address, cerouter.address);

//         await usb.connect(signer3).approve(dao.address, "50" + wad);
//         console.log("hBNB before burn: " + await hBNB.balanceOf(signer2.address))
//         await dao.connect(signer3).buyFromAuction(cetoken.address, 1, "3" + wad, "660000000000000000000000000", signer3.address);
//         console.log("hBNB before burn: " + await hBNB.balanceOf(signer2.address))

//         console.log("AFTER-BUYING");
//         console.log("ceaBNBc: " + await cetoken.balanceOf(signer3.address));
//         console.log("aBNBc  : " + await abnbc.balanceOf(signer3.address));
//     });
// });
