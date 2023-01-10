const {expect} = require("chai");
const {BigNumber} = require('ethers');
const {ethers, upgrades, waffle} = require("hardhat");
const {deployMockContract} = waffle;
const {WeiPerEther, AddressZero, Zero} = ethers.constants;

const MasterVault = require('../../artifacts/contracts/masterVault/MasterVault.sol/MasterVault.json');
const IAddressStore = require('../../artifacts/contracts/stkBNB/interfaces/IAddressStore.sol/IAddressStore.json');
const IStakedBNBToken = require('../../artifacts/contracts/stkBNB/interfaces/IStakedBNBToken.sol/IStakedBNBToken.json');
const IStakePool = require('../../artifacts/contracts/stkBNB/interfaces/IStakePool.sol/IStakePool.json');

describe('StkBnbStrategy', () => {

    describe('MasterVault is EOA', () => {
        let strategist, user, rewards, masterVault, addressStore, stkBNB, stakePool, strategy;

        beforeEach(async () => {
            [strategist, user, rewards, masterVault, ...others] = await ethers.getSigners();
            [addressStore, stkBNB, stakePool, strategy] = await init(strategist, rewards, masterVault);
        });

        it('should init', function () {
            // do nothing, ensures that the before each hook works
        });

        it('should receive only from stakePool or strategist', async () => {
            // sending from user fails
            await expect(user.sendTransaction({
                to: strategy.address,
                value: WeiPerEther
            })).to.be.revertedWith('invalid sender');

            // sending from strategist works
            await strategist.sendTransaction({to: strategy.address, value: WeiPerEther});

            // sending from stakePool works
            const tmpStakePool = rewards;
            await addressStore.mock.getStakePool.returns(tmpStakePool.address);
            await tmpStakePool.sendTransaction({to: strategy.address, value: WeiPerEther});
        });

        async function deposit(amount) {
            await stakePool.mock.deposit.returns();
            await strategy.connect(masterVault).deposit({value: amount});
        }

        describe('deposit', () => {
            it('should work', async () => {
                await deposit(BigNumber.from(1000).add(WeiPerEther)); // 1 eth + dust
                expect(await strategy.balanceOfPool()).to.be.equal(BigNumber.from(98).mul(WeiPerEther).div(100)); // 98% of 1 eth
            });

            it('should fail from anyone other than vault', async () => {
                await expect(strategy.deposit({value: WeiPerEther})).to.be.revertedWith('!vault');
            });

            it('should fail when paused', async () => {
                await strategy.pause();
                await expect(strategy.connect(masterVault).deposit({value: WeiPerEther})).to.be.revertedWith('deposits are paused');
            });
        });

        describe('depositAll', () => {
            it('should work', async () => {
                // there's 0 balance in strategy => nothing to deposit
                await strategy.depositAll();
                expect(await strategy.balanceOfPool()).to.be.equal(BigNumber.from(0));

                // sending 1 eth to strategy
                await strategist.sendTransaction({to: strategy.address, value: WeiPerEther});

                // try depositAll again - should call deposit
                await stakePool.mock.deposit.returns();
                await strategy.depositAll();
                expect(await strategy.balanceOfPool()).to.be.equal(BigNumber.from(98).mul(WeiPerEther).div(100)); // 98% of 1 eth

                // below matcher isn't yet supported: https://github.com/NomicFoundation/hardhat/issues/1135
                // expect('deposit').to.be.calledOnContractWith(stakePool, []);
            });

            it('should fail from anyone other than strategist', async () => {
                await expect(strategy.connect(user).depositAll()).to.be.revertedWith('');
            });

            it('should fail when paused', async () => {
                await strategy.pause();
                await expect(strategy.depositAll()).to.be.revertedWith('deposits are paused');
            });
        });

        describe('withdraw', () => {
            it('should work using only strategy balance', async () => {
                // sending 1 eth to strategy
                let strategyBalance = WeiPerEther;
                await strategist.sendTransaction({to: strategy.address, value: strategyBalance});

                const prevUserBalance = await user.getBalance();
                const amount = 1000;
                await strategy.connect(masterVault).withdraw(user.address, amount);

                expect(await user.getBalance()).to.equal(prevUserBalance.add(amount));
                expect(await ethers.provider.getBalance(strategy.address)).to.equal(strategyBalance.sub(amount));
            });

            it('should work using partial strategy balance', async () => {
                // sending 1 eth to strategy
                const strategyBalance = WeiPerEther;
                await strategist.sendTransaction({to: strategy.address, value: strategyBalance});

                // deposit something to stakePool to make pool balance +ve
                const depositAmt = BigNumber.from(2).mul(WeiPerEther);
                await deposit(depositAmt);

                const prevUserBalance = await user.getBalance();
                const prevPoolBalance = await strategy.balanceOfPool();
                const amount = strategyBalance.mul(2);

                // withdraw
                await stkBNB.mock.send.returns();
                await strategy.connect(masterVault).withdraw(user.address, amount);

                expect(await user.getBalance()).to.equal(prevUserBalance.add(strategyBalance));
                expect(await ethers.provider.getBalance(strategy.address)).to.equal(0);

                [recipient, pendingClaim] = await strategy.withdrawReqs(0);
                expect(recipient).to.equal(user.address);
                expect(pendingClaim).to.equal(BigNumber.from('999999990000000000')); // 0.99 BNB, slightly less than 1 BNB because of the fee calculations
                expect(await strategy.balanceOfPool()).to.be.equal(prevPoolBalance.sub(pendingClaim));
            });

            it('should fail for invalid amount', async () => {
                await expect(strategy.connect(masterVault).withdraw(user.address, 0)).to.be.revertedWith('invalid amount');
            });

            it('should fail from anyone other than vault', async () => {
                await expect(strategy.withdraw(user.address, 1)).to.be.revertedWith('!vault');
            });
        });

        describe('claimAndDistribute', () => {
            it('should work', async () => {
                await stakePool.mock.claimAll.returns();
                strategy.claimAndDistribute();
            });
        });

        describe('claimAll', () => {
            it('should work', async () => {
                await stakePool.mock.claimAll.returns();
                strategy.claimAll();
            });
        });

        describe('claim', () => {
            it('should work', async () => {
                await stakePool.mock.claim.withArgs(0).returns();
                await strategy.claim(0);
            });
        });

        describe('distribute', () => {
            it('should work', async () => {
                let req1 = [user.address, WeiPerEther.mul(3).div(4)]; // 0.75 eth, should get completely fulfilled
                let req2 = [addressStore.address, 1]; // should go to manual withdraw as the mock contract can't receive
                let req3 = [user.address, WeiPerEther.div(2)]; // 0.5 eth, should get partially fulfilled
                await strategy.setupDistribute([req1, req2, req3], {value: WeiPerEther}); // _bnbToDistribute = 1 eth

                const prevUserBalance = await user.getBalance();
                expect(await strategy.startIndex()).to.equal(0); // no request has yet been fulfilled
                expect(await strategy.endIndex()).to.equal(3);

                await strategy.distribute(3);

                expect(await user.getBalance()).to.equal(prevUserBalance.add(WeiPerEther)); // only what was available to distribute got distributed
                expect(await strategy.startIndex()).to.equal(2); // only the first 2 requests were deleted
                expect(await strategy.endIndex()).to.equal(3); // didn't change

                // ensure that the 2nd request went to manual withdraw
                expect(await strategy.manualWithdrawAmount(addressStore.address)).to.equal(1);

                // ensure that the last request was half fulfilled
                [recipient, pendingClaim] = await strategy.withdrawReqs(2);
                expect(recipient).to.equal(user.address);
                expect(pendingClaim).to.equal(WeiPerEther.div(4)); // 0.25 eth
            });

            it('should fail for bad endIdx', async () => {
                await stakePool.mock.claim.withArgs(0).returns();
                await expect(strategy.distribute(1)).to.be.revertedWith('endIdx out of bound');
            });
        });

        describe('distributeManual', () => {
            it('should work', async () => {
                await strategy.setupDistributeManual(user.address, WeiPerEther, {value: WeiPerEther.mul(2)}); // _bnbToDistribute = 2 eth

                const prevUserBalance = await user.getBalance();

                await strategy.distributeManual(user.address);

                expect(await user.getBalance()).to.equal(prevUserBalance.add(WeiPerEther));
                expect(await ethers.provider.getBalance(strategy.address)).to.equal(WeiPerEther);
                expect(await strategy.manualWithdrawAmount(user.address)).to.equal(0);
            });

            it('should fail for 0 recipient amount', async () => {
                await expect(strategy.distributeManual(user.address)).to.be.revertedWith('!distributeManual');
            });

            it('should fail when strategy does not have enough balance', async () => {
                await strategy.setupDistributeManual(user.address, WeiPerEther.mul(2), {value: WeiPerEther}); // _bnbToDistribute = 1 eth
                await expect(strategy.distributeManual(user.address)).to.be.revertedWith('');
            });
        });

        describe('harvest', () => {
            it('should work', async () => {
                const yieldStkBnb = WeiPerEther;
                await stkBNB.mock.balanceOf.withArgs(strategy.address).returns(yieldStkBnb);
                await stkBNB.mock.send.withArgs(rewards.address, yieldStkBnb, []).returns(); // as balance of pool == 0
                await strategy.harvest();
            });

            it('should fail from anyone other than strategist', async () => {
                await expect(strategy.connect(user).harvest()).to.be.revertedWith('');
            });
        });

        describe('calculateYield', () => {
            it('should work', async () => {
                const stkBnbBalance = WeiPerEther;
                await stkBNB.mock.balanceOf.withArgs(strategy.address).returns(stkBnbBalance);
                await deposit(stkBnbBalance.div(2)); // so that we have some balanceOfPool
                expect(await strategy.calculateYield()).to.equal(stkBnbBalance.sub(await strategy.balanceOfPool()));
            });
        });

        describe('balanceOfPool', () => {
            it('should work', async () => {
                expect(await strategy.balanceOfPool()).to.equal(0); // initially

                await deposit(WeiPerEther); // so that we have some balanceOfPool
                expect(await strategy.balanceOfPool()).to.equal(BigNumber.from(98).mul(WeiPerEther).div(100)); // 98% of 1 eth
            });
        });

        describe('canDeposit', () => {
            it('should return true', async () => {
                expect(await strategy.canDeposit(WeiPerEther)).to.equal(true);
            });

            it('should return false', async () => {
                expect(await strategy.canDeposit(1)).to.equal(false);
            });
        });

        describe('assessDepositFee', () => {
            it('should work', async () => {
                expect(await strategy.assessDepositFee(WeiPerEther)).to.equal(BigNumber.from(98).mul(WeiPerEther).div(100)); // 98% of 1 eth
            });
        });

        describe('startIndex', () => {
            it('should work', async () => {
                expect(await strategy.startIndex()).to.equal(0);
            });
        });

        describe('endIndex', () => {
            it('should work', async () => {
                expect(await strategy.endIndex()).to.equal(0);
            });
        });

        describe('changeAddressStore', () => {
            it('should work', async () => {
                await strategy.changeAddressStore(masterVault.address);
            });

            it('should fail on invalid address', async () => {
                await expect(strategy.changeAddressStore(AddressZero)).to.be.revertedWith('');
            });

            it('should fail from anyone other than owner', async () => {
                await expect(strategy.connect(user).changeAddressStore(AddressZero)).to.be.revertedWith('Ownable: caller is not the owner');
            });
        });
    });

    describe('MasterVault is MockContract', () => {
        let strategist, user, rewards, masterVault, addressStore, stkBNB, stakePool, strategy;

        beforeEach(async () => {
            [strategist, user, rewards, ...others] = await ethers.getSigners();
            masterVault = await deployMockContract(strategist, MasterVault.abi);
            [addressStore, stkBNB, stakePool, strategy] = await init(strategist, rewards, masterVault);
        });

        it('should init', function () {
            // do nothing, ensures that the before each hook works
        });

        describe('panic', () => {
            it('should work', async () => {
                // sending 1 eth to strategy
                let strategyBalance = WeiPerEther;
                await strategist.sendTransaction({to: strategy.address, value: strategyBalance});

                await masterVault.mock.strategyParams.withArgs(strategy.address).returns(true, 0, strategyBalance);

                // this reverts, but with `!sent`. This indicates that the panic() did work.
                // It is only an issue with the mocked masterVault contract not being able to `receive`.
                await expect(strategy.panic()).to.be.revertedWith('!sent');
            });

            it('should fail from anyone other than strategist', async () => {
                await expect(strategy.connect(user).panic()).to.be.revertedWith('');
            });
        });
    });

});

async function init(strategist, rewards, masterVault) {
    let addressStore = await deployMockContract(strategist, IAddressStore.abi);
    let stkBNB = await deployMockContract(strategist, IStakedBNBToken.abi);
    let stakePool = await deployMockContract(strategist, IStakePool.abi);

    await addressStore.mock.getStkBNB.returns(stkBNB.address);
    await addressStore.mock.getStakePool.returns(stakePool.address);

    await stakePool.mock.config.returns({
        bcStakingWallet: AddressZero,
        minCrossChainTransfer: Zero,
        transferOutTimeout: Zero,
        minBNBDeposit: WeiPerEther.div(10 ** 6), // 1 micro BNB
        minTokenWithdrawal: WeiPerEther.div(10 ** 6), // 1 micro stkBNB
        cooldownPeriod: Zero,
        fee: {
            reward: BigNumber.from('3000000000'), // 3%
            deposit: BigNumber.from('2000000000'), // 2%
            withdraw: BigNumber.from('1000000000'), // 1%
        }
    });
    await stakePool.mock.exchangeRate.returns([1, 1]); // 1:1 rate

    let strategy = await upgrades.deployProxy(await ethers.getContractFactory('MockStkBnbStrategy'), [
        addressStore.address,
        rewards.address,
        masterVault.address,
        addressStore.address
    ]);
    await strategy.deployed();

    return [addressStore, stkBNB, stakePool, strategy];
}