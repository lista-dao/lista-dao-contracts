const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const web3 = require('web3');

const toBN = web3.utils.toBN;
const { constants } = require('@openzeppelin/test-helpers');


let owner, staker_1, staker_2,
    amount_1, amount_2,
    abnbc, abnbb, wbnb, hbnb, usb, ce_Abnbc_join, collateral, clip,
    ce_vault, ce_token, ce_dao, pool, h_provider, ce_rot;


describe('Helio Provider', () => {
    before(async function () {
        await init();
    });
    describe('Basic functionality', async () => {
        it('staker_1 provides aBNBc', async () => {
            console.log(`------- initial balances and supplies -------`);
            await printBalances();

            // approve before provide in certToken
            await abnbc.connect(staker_1).approve(ce_rot.address, amount_2.toString());
            await expect(
                h_provider.connect(staker_1).provideInABNBc(amount_1.toString())
            ).to.emit(h_provider, "Deposit")
                .withArgs(
                    staker_1.address,
                    amount_1.toString()
                );

            console.log(`------- balances and supplies after deposit aBNBc-------`);
            await printBalances()
        });
        it('Helio operator claims yields', async () => {
            // try to claim 0 rewards
            await expect(
                h_provider.connect(owner).claimInABNBc(staker_2.address)
            ).to.be.revertedWith("has not got yields to claim");
            // change ratio to have yield
            await abnbb.repairRatio(ratio_2.toString());
            // try to claim yields not from operator
            await expect(
                h_provider.connect(staker_2).claimInABNBc(staker_2.address)
            ).to.be.revertedWith("Operator: not allowed");

            // available_yields = (amount_1/ratio_2 - amount_1) in BNB
            // available_yields * ratio_2 -> convert to aBNBc
            available_yields = amount_1.sub(amount_1.mul(ratio_2).div(toBN(1e18)));

            await expect(
                h_provider.connect(owner).claimInABNBc(staker_2.address)
            ).to.emit(h_provider, "Claim")
                .withArgs(
                    staker_2.address,
                    available_yields.toString()
                );

            console.log(`------- balance after yields have been claimed -------`);
            await printBalances();
        });
        it('staker_1 releases ABNBc', async () => {
            console.log();
            await abnbc.connect(staker_1).approve(ce_dao.address, amount_2.toString());
            await abnbc.connect(staker_1).approve(ce_rot.address, amount_2.toString());

            await ce_token.connect(staker_1).approve(h_provider.address, amount_2.toString());

            await expect(
                h_provider.connect(staker_1).releaseInABNBc(staker_1.address, amount_1.div(toBN(100)).toString())
            ).to.emit(h_provider, "Withdrawal")
                .withArgs(
                    staker_1.address,
                    staker_1.address,
                    amount_1.div(toBN(100)).toString()
                );

            console.log(`------- balance after staker_1 released(${amount_1.div(toBN(2)).toString()} aBNBc) -------`);
            await printBalances();
        });
        it('staker_1 provides BNB', async () => {
            const relayerFee = await pool.getRelayerFee();
            ratio = await abnbb.ratio();
            // after stake via binancePool staker receives amount_2 - relayerFee
            await expect(
                h_provider.connect(staker_1).provide({ value: amount_2.toString() })
            ).to.emit(h_provider, "Deposit")
                .withArgs(
                    staker_1.address,
                    amount_2.sub(toBN(relayerFee)).toString()
                );

            console.log(`------- balance after staker_1 provided(${amount_2.toString()} BNB) -------`);
            await printBalances();
        });
        it('staker_1 releases BNB', async () => {
            // try to release less then minimum unstake amount
            await expect(
                h_provider.connect(staker_1).release(staker_1.address, toBN('100000').toString())
            ).to.be.revertedWith("value must be greater than min unstake amount");

            await expect(
                h_provider.connect(staker_1).release(staker_1.address, amount_1.toString())
            ).to.emit(h_provider, "Withdrawal")
                .withArgs(
                    staker_1.address,
                    staker_1.address,
                    amount_1.toString()
                );
            // verify pending releasing of staker_1
            assert.equal(
                (await ce_rot.getPendingWithdrawalOf(staker_1.address)).toString(),
                amount_1.toString()
            );

            console.log(`------- balance after staker_1 provided(${amount_2.toString()} BNB) -------`);
            await printBalances();
        });
    });
    describe('Dao functionality', async () => {
        it('daoBurn()', async () => {
            await expect(
                h_provider.connect(staker_1).daoBurn(staker_1.address, toBN('1000').toString())
            ).to.be.revertedWith("AuctionProxy: not allowed");
            // change DAO to check access easily
            await h_provider.connect(owner).changeProxy(intermediary.address);

            await h_provider.connect(intermediary).daoBurn(staker_1.address, toBN('1000').toString());
        });
        it('daoMint()', async () => {
            await expect(
                h_provider.connect(staker_1).daoMint(staker_1.address, toBN('1000').toString())
            ).to.be.revertedWith("AuctionProxy: not allowed");

            await h_provider.connect(intermediary).daoMint(staker_1.address, toBN('1000').toString());
        });
    });
    describe("Updating functionality", async () => {
        let example_address = "0xF92Ff9DBda8B780a9C7BC2d2b37db9D74D1BAcd6";
        it("change Dao and verify allowances", async () => {
            // try to update from not owner and waiting for a revert
            await expect(
                h_provider.connect(staker_1).changeDao(example_address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
            // update
            await h_provider.connect(owner).changeDao(example_address);
            // check allowances for new Dao
            expect(
                await ce_token.allowance(h_provider.address, example_address)
            ).to.be.equal(constants.MAX_UINT256.toString());
        });
        it('change ceToken and verify allowances', async () => {
            // try to update from not owner and waiting for a revert
            await expect(
                h_provider.connect(staker_1).changeCeToken(example_address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
            /* ceToken */ // deploy mock smart contract
            const CeToken = await ethers.getContractFactory("CeToken");
            mockCeToken = await CeToken.deploy();
            await mockCeToken.initialize("Mock Ceros token", "mock");
            // update
            await h_provider.connect(owner).changeCeToken(mockCeToken.address);
            // check allowances for new Dao
            expect(
                await mockCeToken.allowance(h_provider.address, example_address)
            ).to.be.equal(constants.MAX_UINT256.toString());
        });
        it("change collateral token", async () => {
            // try to update from not owner and waiting for a revert
            await expect(
                h_provider.connect(staker_1).changeCollateralToken(example_address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
            // update
            await expect(
                h_provider.connect(owner).changeCollateralToken(example_address)
            ).to.emit(h_provider, "ChangeCollateralToken")
                .withArgs(example_address);
            // check allowances for new Dao
        });
    });
});

async function init() {
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
    const Usb = await ethers.getContractFactory("USB");
    usb = await Usb.deploy();
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
    const UsbJoin = await ethers.getContractFactory("UsbJoin");
    const usbJoin = await UsbJoin.deploy(vat.address, usb.address);
    /* jug */
    const Jug = await ethers.getContractFactory("Jug");
    const jug = await Jug.deploy(vat.address);
    /* DAO */
    const ceDao = await ethers.getContractFactory("DAOInteraction");
    ce_dao = await ceDao.deploy();
    await ce_dao.initialize(
        vat.address,
        spot.address,
        usb.address,
        usbJoin.address,
        jug.address,
        dog.address,
        '0x76c2f516E814bC6B785Dfe466760346a5aa7bbD1'
    );
    // add dao to vat
    await vat.rely(ce_dao.address);
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
}

async function printBalances() {
    bnb_balance = await waffle.provider.getBalance(staker_1.address);
    console.log(`BNB balance(staker_1): ${bnb_balance.toString()}`);
    // aBNBc balance of staker_1
    console.log(`balance of staker_1 in aBNBc: ${(await abnbc.balanceOf(staker_1.address)).toString()}`);
    // aBNBc balance of ce_vault
    console.log(`balance of ce_vault in aBNBc: ${(await abnbc.balanceOf(ce_vault.address)).toString()}`);
    // hBNB balance of staker_1
    console.log(`balance of staker_1 in hBNB: ${(await hbnb.balanceOf(staker_1.address)).toString()}`);
    // hBNB supply
    console.log(`supply hBNB: ${(await hbnb.totalSupply()).toString()}`);
    // ceToken balance of staker_1
    console.log(`balance of staker_1 in ceToken: ${(await ce_token.balanceOf(staker_1.address)).toString()}`);
    // ceToken supply
    console.log(`supply ceToken: ${(await ce_token.totalSupply()).toString()}`);
    // Available rewards
    console.log(`yield for staker_1: ${(await ce_vault.getYieldFor(staker_1.address)).toString()}`);
    console.log(`yield for helio: ${(await ce_vault.getYieldFor(h_provider.address)).toString()}`);
    console.log(`current ratio: ${(await abnbb.ratio()).toString()}`);
}