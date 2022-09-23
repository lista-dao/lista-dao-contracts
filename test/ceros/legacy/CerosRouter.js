const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const web3 = require('web3');

const toBN = web3.utils.toBN;
const { constants } = require('@openzeppelin/test-helpers');

let owner, staker_1, staker_2,
    amount_1, amount_2, ratio, available_yields, profit,
    abnbc, abnbb, wbnb, hay, ce_Abnbc_join, collateral, clip,
    ce_vault, ce_token, ce_dao, pool, ce_rot, auctionProxy;


describe('Ceros Router', () => {
    before(async function () {
        await init();
    });
    describe('Basic functionality', async () => {
        it('staker_1 deposits aBNBc', async () => {
            console.log(`------- initial balances and supplies -------`);
            await printBalances();
            await abnbc.connect(staker_1).approve(ce_rot.address, amount_2.toString());
            await ce_rot.connect(staker_1).depositABNBc(amount_1.toString());
            console.log(`------- balances and supplies after deposit 1 aBNBc-------`);
            await printBalances()
            // balance of staker_1 in cetoken should has increased
            assert.equal((await ce_token.balanceOf(staker_1.address)).toString(), amount_1.toString());
            // supply in vault
            assert.equal((await ce_token.totalSupply()).toString(), amount_1.toString());
        });
        it('claim yields for staker_1', async () => {
            // try to claim 0 rewards
            await expect(
                ce_rot.connect(staker_2).claim(staker_2.address)
            ).to.be.revertedWith("has not got yields to claim");
            // change ratio to have some yield
            await abnbb.repairRatio(ratio_2.toString());
            console.log(`------- balances after ratio has been changed -------`);
            await printBalances();
            // available_yields = (amount_1/ratio_2 - amount_1) in BNB
            // available_yields * ratio_2 -> convert to aBNBc
            available_yields = amount_1.sub(amount_1.mul(ratio_2).div(toBN(1e18)));
            // claim to third address
            await expect(
                ce_rot.connect(staker_1).claim(intermediary.address)
            ).to.emit(ce_rot, "Claim")
                .withArgs(intermediary.address, abnbc.address, available_yields.toString());
            // check balance of the third address in certToken(aBNBc)
            assert.equal(
                (await abnbc.balanceOf(intermediary.address)).toString(),
                available_yields.toString()
            );
            // amount of certToken in Vault should has been reduced
            assert.equal(
                (await abnbc.balanceOf(ce_vault.address)).toString(),
                amount_1.sub(available_yields).toString()
            );
            console.log(`------- balance after yields have been claimed -------`);
            await printBalances();
        });
        it('staker_1 deposits 1 BNB(via Staking Pool)', async () => {
            const relayerFee = await pool.getRelayerFee();
            // realAmount = ((amount - relayerFee) * ratio) / 1e18;
            ratio = await abnbb.ratio();
            const realAmount = (amount_1.sub(toBN(relayerFee))).mul(toBN(ratio)).div(toBN(1e18));

            await expect(
                ce_rot.connect(staker_1).deposit({ value: amount_1.toString() })
            ).to.emit(ce_rot, "Deposit")
                .withArgs(
                    staker_1.address,
                    wbnb.address,
                    realAmount.toString(),
                    '0'
                );
            // supply in CeVault and balances should have been changed
            assert.equal(
                (await abnbc.balanceOf(ce_vault.address)).toString(),
                amount_1.sub(available_yields).add(realAmount).toString()
            );
            // staker_1 receives amount in BNB therefore:
            // to_receive = realAmount * 1e18 / ratio;
            assert.equal(
                (await ce_token.balanceOf(staker_1.address)).toString(),
                amount_1.add(realAmount.mul(toBN(1e18)).div(toBN(ratio))).toString()
            );
            console.log(`------- balance after staker_1 deposited 1 BNB(Staking Pool) -------`);
            await printBalances();
        });
        it('staker_1 deposits less then 1 BNB and receives amount after changing on Dex with some profit', async () => {
            const resp = await dex.getAmountsOut(amount_1.toString(), [wbnb.address, abnbc.address]);
            const dexABNBc = toBN(resp[1]);
            const balanceOfStaker_1_before = toBN(await ce_token.balanceOf(staker_1.address));
            const vaultSupply_before = toBN(await abnbc.balanceOf(ce_vault.address));

            // get returned amount from BinancePool
            // poolABNBcAmount = ((amount - relayerFee) * ratio) / 1e18;
            // update relayer fee to make some profit from DEX
            await pool.changeRelayerFee(toBN(1e19).sub(toBN(8e17)).toString());

            ratio = await abnbb.ratio();
            const relayerFee = await pool.getRelayerFee();

            const poolABNBc = (amount_1.sub(toBN(relayerFee))).mul(toBN(ratio)).div(toBN(1e18));
            console.log(`returned amount from BinancePool(in aBNBc): ${poolABNBc.toString()}`);
            console.log(`dexABNBc > poolABNBc: ${dexABNBc.cmp(poolABNBc).toString()}`);
            profit = dexABNBc.sub(poolABNBc).toString();

            await expect(
                ce_rot.connect(staker_1).deposit({ value: amount_1.toString() })
            ).to.emit(ce_rot, "Deposit")
                .withArgs(
                    staker_1.address,
                    wbnb.address,
                    poolABNBc.toString(),
                    profit
                );
            // check supply in the CeVault
            assert.equal(
                (await abnbc.balanceOf(ce_vault.address)).toString(),
                vaultSupply_before.add(poolABNBc).toString()
            );
            // check balance of staker_1 in BNB and CeToken
            assert.equal(
                (await ce_token.balanceOf(staker_1.address)).toString(),
                balanceOfStaker_1_before.add(poolABNBc.mul(toBN(1e18)).div(toBN(ratio))).toString()
            );
            console.log(`------- balance after staker_1 deposited 1 BNB(Dex) -------`);
            await printBalances();
        });
        it('staker_1 claimes profit', async () => {
            // check available profit
            const available_profit = (await ce_rot.getProfitFor(staker_1.address)).toString();
            assert.equal(available_profit, profit, "profit for staker_1 is wrong");
            await expect(
                ce_rot.connect(staker_1).claimProfit(staker_1.address)
            ).to.emit(ce_rot, "Claim")
                .withArgs(staker_1.address, abnbc.address, profit);
            // try to claim again
            await expect(
                ce_rot.connect(staker_1).claimProfit(staker_1.address)
            ).to.be.revertedWith("has not got a profit");
            console.log(`------- balance after staker_1 claimed profit(${profit.toString()} aBNBc) -------`);
            await printBalances();
        });
        it('staker_1 withdraws aBNBc', async () => {
            const balanceOfStaker_1_before = toBN(await ce_token.balanceOf(staker_1.address));
            const vaultSupply_before = toBN(await abnbc.balanceOf(ce_vault.address));

            const to_withdraw = vaultSupply_before.div(toBN(2)).mul(toBN(1e18)).div(toBN(ratio));
            await expect(
                ce_rot.connect(staker_1).withdrawABNBc(staker_1.address, to_withdraw.toString())
            ).to.emit(ce_rot, "Withdrawal")
                .withArgs(
                    staker_1.address,
                    staker_1.address,
                    abnbc.address,
                    vaultSupply_before.div(toBN(2)).toString()
                );
            // check supply in the CeVault
            assert.equal(
                (await abnbc.balanceOf(ce_vault.address)).toString(),
                vaultSupply_before.div(toBN(2)).toString()
            );
            // check balance of staker_1 in BNB and CeToken
            assert.equal(
                (await ce_token.balanceOf(staker_1.address)).toString(),
                balanceOfStaker_1_before.sub(
                    (vaultSupply_before.div(toBN(2))).mul(toBN(1e18)).div(toBN(ratio))
                ).toString()
            );
            console.log(`------- balance after staker_1 withdrawn aBNBc(${vaultSupply_before.div(toBN(2)).toString()}) -------`);
            await printBalances();
        });
        it('staker_1 withdraws BNB', async () => {
            const balanceOfStaker_1_before = toBN(await ce_token.balanceOf(staker_1.address));
            const vaultSupply_before = toBN(await abnbc.balanceOf(ce_vault.address));

            ratio = toBN(await abnbb.ratio());

            await expect(
                await ce_rot.connect(staker_1).withdraw(staker_1.address, amount_1.div(toBN(2)).toString())
            ).to.emit(ce_rot, "Withdrawal")
                .withArgs(
                    staker_1.address,
                    staker_1.address,
                    wbnb.address,
                    amount_1.div(toBN(2)).toString()
                );
            // check supply in the CeVault
            assert.equal(
                (await abnbc.balanceOf(ce_vault.address)).toString(),
                vaultSupply_before.sub(amount_1.div(toBN(2)).mul(ratio).div(toBN(1e18))).toString()
            );
            // check balance of staker_1 in BNB and CeToken
            assert.equal(
                (await ce_token.balanceOf(staker_1.address)).toString(),
                balanceOfStaker_1_before.sub(amount_1.div(toBN(2))).toString()
            );
            // check pending withdrawal of staker_1
            assert.equal(
                (await ce_rot.getPendingWithdrawalOf(staker_1.address)).toString(),
                amount_1.div(toBN(2)).toString()
            );
            console.log(`------- balance after staker_1 withdrawn BNB(${amount_1.div(toBN(2)).toString()}) -------`);
            await printBalances();
        });
        it('staker_1 withdraws BNB with slippage from DEX', async () => {
            // get dex outAmount
            let resp = await dex.getAmountsOut(amount_1.toString(), [abnbc.address, wbnb.address]);
            console.log(`returned amount from DEX(in aBNBc): ${toBN(resp[1]).toString()} `);
            // try to withdraw more than have in the CeVault
            await expect(
                ce_rot.connect(staker_1).withdrawWithSlippage(staker_1.address, amount_1.toString(), toBN(resp[1]).toString())
            ).to.be.revertedWith("not such amount in the vault");

            // Calculation for the third param of CerosRouter.withdrawWithSlippage():
            // 1. get current ratio
            // 2. realAmount = amount * ratio / 1e18;
            // 3. outAmount = (await dex.getAmountsOut(to_withdraw.toString(), [abnbc.address, wbnb.address]))[1];

            // in Our case:
            const to_withdraw = toBN("100000");
            const ratio = toBN(await abnbb.ratio());
            const realAmount = to_withdraw.mul(ratio).div(toBN(1e18));

            // get dex outAmount
            resp = await dex.getAmountsOut(realAmount.toString(), [abnbc.address, wbnb.address]);
            await expect(
                ce_rot.connect(staker_1).withdrawWithSlippage(staker_1.address, to_withdraw.toString(), toBN(resp[1]).toString())
            ).to.emit(ce_rot, "Withdrawal")
                .withArgs(
                    staker_1.address,
                    staker_1.address,
                    wbnb.address,
                    toBN(resp[1]).toString()
                );
            console.log(`------- balance after staker_1 withdrawn BNB(${to_withdraw.toString()}) -------`);
            await printBalances();
        });
        it('deposit and withdrawal as via HelioProvider(mock)', async () => {
            // without needed allowances
            await expect(
                ce_rot.connect(intermediary).depositABNBcFrom(staker_1.address, amount_1.toString())
            ).to.be.revertedWith("Provider: not allowed");

            await ce_rot.connect(owner).changeProvider(intermediary.address);
            // approve to spend
            // abnbc.connect(staker_1).approve(intermediary.address, amount_1.toString());
            abnbc.connect(staker_1).approve(ce_rot.address, amount_1.toString());

            await expect(
                ce_rot.connect(intermediary).depositABNBcFrom(staker_1.address, amount_1.toString())
            ).to.emit(ce_rot, "Deposit").withArgs(
                intermediary.address,
                abnbc.address,
                amount_1.toString(),
                '0'
            );
            console.log(`------- balances and supplies after deposit aBNBc(${amount_1.toString()})------- `);
            await printBalances();
            await expect(
                ce_rot.connect(intermediary).withdrawFor(staker_1.address, amount_1.div(toBN(2)).toString())
            ).to.emit(ce_rot, "Withdrawal").withArgs(
                intermediary.address,
                staker_1.address,
                wbnb.address,
                amount_1.div(toBN(2)).mul(ratio).div(toBN(1e18)).toString()
            );
            console.log(`------- balances and supplies after deposit aBNBc(${amount_1.div(toBN(2)).toString()})------- `);
            await printBalances();
        });
    });
    describe("Updating functionality", async () => {
        let example_address = "0xF92Ff9DBda8B780a9C7BC2d2b37db9D74D1BAcd6";
        it("change Provider", async () => {
            // try to update from not owner and waiting for a revert
            await expect(
                ce_rot.connect(staker_1).changeProvider(example_address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
            // update
            await ce_rot.connect(owner).changeProvider(example_address);
        });
        it('change Pool and verify allowances', async () => {
            // try to update from not owner and waiting for a revert
            await expect(
                ce_rot.connect(staker_1).changePool(example_address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
            // update
            await ce_rot.connect(owner).changePool(example_address);
            // check allowances for new Dao
            expect(
                await abnbc.allowance(ce_rot.address, example_address)
            ).to.be.equal(constants.MAX_UINT256.toString());
        });
        it("change Dex and verify allowancesken", async () => {
            example_address = "0x66bea595aefd5a65799a920974b377ed20071118";
            // try to update from not owner and waiting for a revert
            await expect(
                ce_rot.connect(staker_1).changeDex(example_address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
            // update
            await ce_rot.connect(owner).changeDex(example_address);
            // check allowances for new Dao
            expect(
                await abnbc.allowance(ce_rot.address, example_address)
            ).to.be.equal(constants.MAX_UINT256.toString());
            expect(
                await wbnb.allowance(ce_rot.address, example_address)
            ).to.be.equal(constants.MAX_UINT256.toString());
            // for previous Dex allowances should be rollback to zero
            expect(
                await abnbc.allowance(ce_rot.address, ce_dao.address)
            ).to.be.equal('0');
            expect(
                await wbnb.allowance(ce_rot.address, ce_dao.address)
            ).to.be.equal('0');
        });
        it("change vault and verify allowancesken", async () => {
            example_address = "0xcb0006b31e6b403feeec257a8abee0817bed7eba";
            // try to update from not owner and waiting for a revert
            await expect(
                ce_rot.connect(staker_1).changeVault(example_address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
            // update
            await ce_rot.connect(owner).changeVault(example_address);
            // check allowances for new vault
            expect(
                await abnbc.allowance(ce_rot.address, example_address)
            ).to.be.equal(constants.MAX_UINT256.toString());
            // previous vault allowances should be rolled back to zero
            expect(
                await wbnb.allowance(ce_rot.address, ce_vault.address)
            ).to.be.equal('0');
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
    /* HAY */
    const Hay = await ethers.getContractFactory("Hay");
    hay = await Hay.deploy(97, "HAY");
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
    /* hayJoin */
    const HayJoin = await ethers.getContractFactory("HayJoin");
    const hayJoin = await HayJoin.deploy(vat.address, hay.address);
    /* jug */
    const Jug = await ethers.getContractFactory("Jug");
    const jug = await Jug.deploy(vat.address);
    /* Auction */
    const AuctionProxy = await ethers.getContractFactory("AuctionProxy");
    auctionProxy = await AuctionProxy.deploy();
    /* DAO */
    const ceDao = await ethers.getContractFactory("Interaction", {
        unsafeAllow: ['external-library-linking'],
            libraries: {
            AuctionProxy: auctionProxy.address
        },
    });
    ce_dao = await ceDao.deploy();
    await ce_dao.initialize(
        vat.address,
        spot.address,
        hay.address,
        hayJoin.address,
        jug.address,
        dog.address,
        '0x76c2f516E814bC6B785Dfe466760346a5aa7bbD1',
        auctionProxy.address
    );
    // add dao to vat
    await vat.rely(ce_dao.address);
    await vat.rely(spot.address);
    await vat.rely(hayJoin.address);
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
    console.log(`balance of CeVault in aBNBc: ${(await abnbc.balanceOf(ce_vault.address)).toString()}`);
    // ceToken balance of staker_1
    console.log(`balance of staker_1 in ceToken: ${(await ce_token.balanceOf(staker_1.address)).toString()}`);
    // ceToken supply
    console.log(`supply ceToken: ${(await ce_token.totalSupply()).toString()} `);
    // Available rewards
    console.log(`yield for staker_1: ${(await ce_vault.getYieldFor(staker_1.address)).toString()}`);
    console.log(`current ratio: ${(await abnbb.ratio()).toString()}`);
}
