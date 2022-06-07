const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const web3 = require('web3');

const toBN = web3.utils.toBN;
const { constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

let owner, staker_1, staker_2,
    amount_1, amount_2, deposited_amount,
    abnbc, abnbb, wbnb, hbnb, usb, ce_Abnbc_join, collateral, clip,
    ce_vault, ce_token, ce_dao, pool, h_provider, ce_rot;


describe('Routers(HELIO,CEROS)', () => {
    before(async function () {
        [owner, intermediary, bc_operator, staker_1, staker_2, operator] = await ethers.getSigners();
        /* ceToken */
        const CeToken = await ethers.getContractFactory("CeToken");
        ce_token = await CeToken.deploy();
        await ce_token.initialize("Ceros token", "ceAbnbc");
        /* aBNBb */
        const aBNBb = await ethers.getContractFactory("aBNBb");
        abnbb = await aBNBb.deploy();
        await abnbb.initialize(owner.address);
        /* aBNBc */
        const aBNBc = await ethers.getContractFactory("aBNBc");
        abnbc = await aBNBc.deploy();
        await abnbc.initialize(constants.ZERO_ADDRESS, abnbb.address);
        await abnbb.changeABNBcToken(abnbc.address);
        /* wBNB */
        const wBNB = await ethers.getContractFactory("wBNB");
        wbnb = await wBNB.deploy();
        /* USB */
        const Usb = await ethers.getContractFactory("Hay");
        usb = await Usb.deploy(97, "USB");
        /* hBNB */
        const hBNB = await ethers.getContractFactory("hBNB");
        hbnb = await hBNB.deploy();
        await hbnb.initialize();
        /* DEX */
        const Factory = await ethers.getContractFactory("PancakeFactory");
        const factory = await Factory.deploy(owner.address);
        const Router = await ethers.getContractFactory("PancakeRouter");
        dex = await Router.deploy(factory.address, wbnb.address);
        // mint tokens
        await abnbc.mint(owner.address, toBN(5e18).toString());
        await wbnb.mint(owner.address, toBN(5e18).toString());
        // approve
        await abnbc.approve(dex.address, toBN(5e18).toString());
        await wbnb.approve(dex.address, toBN(5e18).toString());

        const reserve_0 = toBN('1000000000000000000');
        await dex.addLiquidityETH(abnbc.address,
            reserve_0.toString(), reserve_0.div(toBN(2)).toString(), reserve_0.toString(),
            owner.address, 9999999999, { value: reserve_0.toString() }
        );
        /* vat */
        const Vat = await ethers.getContractFactory("Vat");
        const vat = await Vat.deploy();
        /* dog */
        const Dog = await ethers.getContractFactory("Dog");
        const dog = await Dog.deploy(vat.address);
        /* spot */
        const Spot = await ethers.getContractFactory("Spotter");
        const spot = await Spot.deploy(vat.address);
        /* usbJoin */
        const UsbJoin = await ethers.getContractFactory("HayJoin");
        const usbJoin = await UsbJoin.deploy(vat.address, usb.address);
        /* jug */
        const Jug = await ethers.getContractFactory("Jug");
        const jug = await Jug.deploy(vat.address);
        /* DAO */
        const ceDao = await ethers.getContractFactory("Interaction");
        ce_dao = await ceDao.deploy();
        await ce_dao.initialize(
            vat.address,
            spot.address,
            usb.address,
            usbJoin.address,
            jug.address,
            dog.address,
        );
        // add dao to vat
        await vat.rely(ce_dao.address);
        await vat.rely(spot.address);
        await vat.rely(usbJoin.address);
        await vat.rely(jug.address);
        await vat.rely(dog.address);
        //
        collateral = ethers.utils.formatBytes32String("ceABNBc");
        /* clip */
        const Clipper = await ethers.getContractFactory("Clipper");
        clip = await Clipper.deploy(vat.address, spot.address, dog.address, collateral);
        /* gemJoin */
        const GemJoin = await ethers.getContractFactory("GemJoin");
        ce_Abnbc_join = await GemJoin.deploy(vat.address, collateral, ce_token.address);
        await ce_dao.setCollateralType(ce_token.address, ce_Abnbc_join.address, collateral, clip.address);
        /* BinancePool */
        const BinancePool = await ethers.getContractFactory("BinancePool");
        pool = await BinancePool.deploy();
        await pool.initialize(owner.address, bc_operator.address, 60 * 60);
        //
        await pool.changeBondContract(abnbb.address);
        await abnbb.changeBinancePool(pool.address);
        await abnbb.changeABNBcToken(abnbc.address);
        await abnbb.changeSwapFeeParams(owner.address, '10000000000000000');
        await pool.changeCertContract(abnbc.address);

        // INIT
        ratio_1 = toBN(1e18);
        ratio_2 = toBN(1e17);
        ratio_3 = toBN(1e15);

        amount_1 = toBN('10000000020000000000');
        amount_2 = toBN('20000000020000000000');

        /* ceVault */
        const ceVault = await ethers.getContractFactory("CeVault");
        ce_vault = await ceVault.deploy();
        await ce_vault.initialize("CeVault", ce_token.address, abnbc.address);
        // set vault for ceABNBc
        await ce_token.changeVault(ce_vault.address);
        /* CeRot */
        const CeRot = await ethers.getContractFactory("CerosRouter");
        ce_rot = await CeRot.deploy();
        await ce_rot.initialize(abnbc.address, wbnb.address, ce_token.address, abnbb.address,
            ce_vault.address, dex.address, pool.address);
        /* HProvider */
        const HProvider = await ethers.getContractFactory("HelioProvider");
        h_provider = await HProvider.deploy();
        await h_provider.initialize(hbnb.address, abnbc.address, ce_token.address, ce_rot.address, ce_dao.address, pool.address);

        await ce_rot.changeProvider(h_provider.address);
        await hbnb.changeMinter(h_provider.address);
        await ce_vault.changeRouter(ce_rot.address);
        // MINT aBNBc
        await abnbb.connect(staker_1).mintBonds(staker_1.address, amount_2.mul(toBN(5)).toString());
        await abnbb.unlockSharesFor(staker_1.address, amount_2.mul(toBN(2)).toString());
    });

    describe('Basic', async () => {
        it('deposit aBNBc via HProvider(HELIO)', async () => {
            await abnbc.connect(staker_1).approve(ce_dao.address, amount_2.toString());
            await abnbc.connect(staker_1).approve(ce_rot.address, amount_2.toString());
            await h_provider.connect(staker_1).provideInABNBc(amount_1.toString());
            // await printBalances()
        });
        it('deposit aBNBc via CeRouter(CEROS)', async () => {
            await abnbc.connect(staker_1).approve(ce_dao.address, amount_2.toString());
            await abnbc.connect(staker_1).approve(ce_rot.address, amount_2.toString());
            //
            await ce_rot.connect(staker_1).depositABNBc(amount_1.toString());
            //await printBalances()
        });
        it('claim yields for user via CeRouter(CEROS)', async () => {
            // change ratio
            await abnbb.repairRatio(ratio_2.toString());
            //     await printBalances()
            await ce_rot.connect(staker_1).claim(staker_1.address);
        });
        it('claim yields for Helio operator via HProvider(HELIO)', async () => {
            await h_provider.connect(owner).claimInABNBc(staker_2.address);
            await printBalances()
        });
        it('withdraw ABNBc via CeRouter(CEROS)', async () => {
            await abnbc.connect(staker_1).approve(ce_dao.address, amount_2.toString());
            await abnbc.connect(staker_1).approve(ce_rot.address, amount_2.toString());
            await ce_token.connect(staker_1).approve(ce_rot.address, amount_2.toString());
            //
            tx = await ce_rot.connect(staker_1).withdrawABNBc(staker_1.address, amount_1.toString());
            await printBalances();
        });
        it('release ABNBc via HProvider(HELIO)', async () => {
            await abnbc.connect(staker_1).approve(ce_dao.address, amount_2.toString());
            await abnbc.connect(staker_1).approve(ce_rot.address, amount_2.toString());
            await ce_token.connect(staker_1).approve(h_provider.address, amount_2.toString());
            //
            await h_provider.connect(staker_1).releaseInABNBc(staker_1.address, amount_1.toString());
            await printBalances();
            //       const bal = await abnbc.balanceOf(staker_1.address);
            //     console.log(`!!!! balance in BNB: ${bal.div(toBN(ratio_2.toString())).toString()}}`);
        });
        it('deposit BNB via CeRouter(CEROS)', async () => {
            await abnbb.repairRatio('982568007076869294');
            await ce_rot.connect(staker_1).deposit({ value: amount_1.toString() });
            await printBalances();
        });
        it('deposit BNB via HProvider(HELIO)', async () => {
            await h_provider.connect(staker_1).provide({ value: amount_1.toString() });
            await printBalances();
        });
        it('release BNB via HProvider(HELIO)', async () => {
            tx = await h_provider.connect(staker_1).provide({ value: amount_2.toString() });
            await printBalances();
            tx = await h_provider.connect(staker_1).release(staker_1.address, amount_1.toString());
            await printBalances();
        });
        it('withdraw BNB via CeRouter(CEROS)', async () => {
            //    tx = await ce_rot.connect(staker_1).deposit({ value: amount_2.toString() });
            //  await printBalances();
            tx = await ce_rot.connect(staker_1).withdraw(staker_1.address, amount_1.div(toBN(2)).toString());
            await printBalances();
        });
    });
});


async function printBalances() {
    bnb_balance = await waffle.provider.getBalance(staker_1.address);
    console.log(`BNB balance(staker_1): ${bnb_balance.toString()}`);
    // aBNBc balance of staker_1
    console.log(`balance in aBNBc staker_1: ${(await abnbc.balanceOf(staker_1.address)).toString()}`);
    // aBNBc balance of ce_vault
    console.log(`balance in aBNBc ce_vault: ${(await abnbc.balanceOf(ce_vault.address)).toString()}`);
    // hBNB balance of staker_1
    console.log(`balance in hbnb staker_1: ${(await hbnb.balanceOf(staker_1.address)).toString()}`);
    // hBNB supply
    console.log(`supply hbnb: ${(await hbnb.totalSupply()).toString()}`);
    // ceToken balance of staker_1
    console.log(`balance in cetoken staker_1: ${(await ce_token.balanceOf(staker_1.address)).toString()}`);
    // ceToken supply
    console.log(`supply ceToken: ${(await ce_token.totalSupply()).toString()}`);
    // Available rewards
    console.log(`yield for staker_1: ${(await ce_vault.getYieldFor(staker_1.address)).toString()}`);
    console.log(`yield for helio: ${(await ce_vault.getYieldFor(h_provider.address)).toString()}`);
    console.log(`current ratio: ${(await abnbb.ratio()).toString()}`);
}