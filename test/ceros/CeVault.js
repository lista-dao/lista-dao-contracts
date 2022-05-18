// const ceVault = artifacts.require('CeVault');
// const ceToken = artifacts.require("CeToken");
// const aBNBc = artifacts.require("aBNBc");
// const aBNBb = artifacts.require("aBNBb");
//
// const toBN = web3.utils.toBN;
// const { constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
//
// let owner, staker_1, staker_2,
//     amount_1, amount_2, amount_3, bal, deposited = toBN('0'),
//     ce_vault, ce_token, abnbc, abnbb,
//     ratio, ratio_1, ratio_2, ratio_3, ratio_4, ratio_5;
//
//
// async function init(accounts) {
//     [owner, staker_1, staker_2] = accounts;
//
//     ratio_1 = toBN(1e18);
//     ratio_2 = toBN('800000000000000000');
//     ratio_3 = toBN('700000000000000000');
//     ratio_4 = toBN('600000000000000000');
//     ratio_5 = toBN('300000000000000000');
//
//     amount_1 = toBN(1e18);
//     amount_2 = toBN('2000000002000000000');
//     amount_3 = toBN('100000000000000');
//
//     // deploy mock aBNBb
//     abnbb = await aBNBb.new();
//     await abnbb.initialize(owner);
//     // deploy mock aBNBc
//     abnbc = await aBNBc.new();
//     await abnbc.initialize(constants.ZERO_ADDRESS, abnbb.address);
//     await abnbb.changeABNBcToken(abnbc.address);
//
//     /* ceToken */
//     ce_token = await ceToken.new();
//     await ce_token.initialize("ceros token", "ceToken");
//     /* ceVault */
//     ce_vault = await ceVault.new();
//     await ce_vault.initialize("CeVault", ce_token.address, abnbc.address);
//     // set vault for ceABNBc
//     await ce_token.changeVault(ce_vault.address);
//     // change router
//     await ce_vault.changeRouter(owner);
// }
//
// async function mintTokens() {
//     await abnbc.mintApprovedTo(staker_1, ce_vault.address, amount_2.mul(toBN(2)), { from: staker_1 });
//     await abnbc.mintApprovedTo(staker_2, ce_vault.address, amount_2.mul(toBN(2)), { from: staker_2 });
// }
//
// async function initBalances(accounts) {
//     await init(accounts);
//     await mintTokens();
// }
//
// async function printBalances() {
//     ratio = await ce_vault.ratio();
//     console.log(`current ratio: ${ratio.toString()}`);
//     const principalPart = await ce_vault.getPrincipalOf(staker_1);
//     console.log(`principal(staker_1): ${principalPart.toString()} `);
//     const yieldFor = await ce_vault.getYieldFor(staker_1);
//     console.log(`yieldFor(staker_1): ${yieldFor.toString()} `);
//     console.log(`principal + yield(staker_1): ${yieldFor.add(principalPart).toString()}`);
//     bal = await ce_vault.getTotalAmountInVault();
//     console.log(`total in vault(abnbc): ${bal.toString()}`);
//     bal = await ce_token.balanceOf(staker_1);
//
//     console.log(`max to withdrawal: ${ratio.mul(bal).div(toBN(1e18)).toString()}`);
//
//     claimed = await ce_vault.getClaimedOf(staker_1);
//     console.log(`claimed of staker_1 in vault: ${claimed.toString()}`);
//
//     const deposit = await ce_vault.getDepositOf(staker_1);
//     console.log(`deposit of staker_1 in vault: ${deposit.toString()}`);
//     console.log(`ceTokenBalanceOf(staker_1): ${(await ce_vault.getCeTokenBalanceOf(staker_1)).toString()}`);
//     console.log(`balance in ceToken: ${bal.toString()}`);
//     console.log(`deposited in aBNBc: ${deposited.toString()}`);
// }
//
// contract('CeVault', (accounts) => {
//     describe('Basic functionality', async () => {
//
//         before(async function () {
//             return initBalances(accounts);
//         });
//         it('get vault name', async () => {
//             assert.equal(
//                 (await ce_vault.getName()).toString(), 'CeVault',
//                 'the vault name is wrong'
//             );
//         });
//         it('update ratio -> deposit', async () => {
//             await ce_vault.deposit(staker_1, amount_1.toString(), { from: staker_1 });
//             deposited = deposited.add(amount_1);
//             console.log('-------balance after deposit 1 BNB from staker_1-------');
//             await printBalances();
//         });
//         it('update ratio', async () => {
//             // update ratio
//             await abnbb.repairRatio(ratio_2.toString());
//             await ce_vault.updateRatio();
//             console.log('-------balance after ratio was changed-------');
//             await printBalances();
//         });
//         // rewards should not descrease after claim
//         it('claim yields', async () => {
//             await expectRevert(
//                 ce_vault.claimYieldsFor(staker_1, staker_1, { from: staker_1 }),
//                 'Not allowed: your are not router',
//             );
//             await ce_vault.claimYieldsFor(staker_1, staker_1, { from: owner });
//             await expectRevert(
//                 ce_vault.claimYields(staker_1),
//                 "hasn't got yields to claim",
//             );
//             console.log('-------balances after yields were claimed-------');
//             await printBalances();
//         });
//         // rewards should not descrease after claim
//         it('update ratio -> print balances', async () => {
//             // update ratio
//             await abnbb.repairRatio(ratio_3.toString());
//             await ce_vault.updateRatio();
//             console.log('-------balance after ratio was changed-------');
//             await printBalances();
//         });
//         it('try to withdrawal more than have and owner of cetoken', async () => {
//             // try to withdrawal more than have
//             await expectRevert(
//                 ce_vault.withdrawal(staker_1, (await ce_token.balanceOf(staker_1)).mul(toBN(2)).toString(), { from: staker_1 }),
//                 'not such amount in the vault',
//             );
//             // transfer to staker_2
//             await ce_token.transfer(staker_2, (await ce_token.balanceOf(staker_1)).toString(), { from: staker_1 });
//             // try to withdrawal
//             await expectRevert(
//                 ce_vault.withdrawal(
//                     staker_1,
//                     (await ce_token.balanceOf(staker_2)).toString(),
//                     { from: staker_2 }
//                 ),
//                 'insufficient balance',
//             );
//             // transfer back to staker_1
//             await ce_token.transfer(staker_1, (await ce_token.balanceOf(staker_2)).toString(), { from: staker_2 });
//         });
//         it('try to withdrawal more than have and owner of cetoken', async () => {
//             const to_withdrawal = (await ce_token.balanceOf(staker_1)).mul(ratio).div(toBN(1e18)).toString();
//             console.log(`to withdrawal: ${to_withdrawal}`);
//             tx = await ce_vault.withdrawal(
//                 staker_1,
//                 (await ce_token.balanceOf(staker_1)).toString(),
//                 { from: staker_1 }
//             );
//             console.log(`withdrawn: ${tx.logs['0'].args.value.toString()}`);
//             console.log('-------balance after withdrawal full-------');
//             await printBalances();
//         });
//         it('claim left yields', async () => {
//             await ce_vault.claimYields(staker_1, { from: staker_1 });
//             console.log('-------balances after yields were claimed-------');
//             await printBalances();
//         });
//         it('update ratio(ratio_4)', async () => {
//             // update ratio
//             await abnbb.repairRatio(ratio_4.toString());
//             await ce_vault.updateRatio();
//             console.log('-------balance after ratio was changed-------');
//             await printBalances();
//         });
//         it('deposit more(1BNB)', async () => {
//             deposited = deposited.add(amount_1);
//             // deposit
//             await ce_vault.deposit(staker_1, amount_1.toString(), { from: staker_1 });
//             console.log('-------balance after deposit 1 BNB from staker_1-------');
//             await printBalances();
//         });
//         it('update ratio(ratio_5)', async () => {
//             // update ratio
//             await abnbb.repairRatio(ratio_5.toString());
//             await ce_vault.updateRatio();
//             console.log('-------balance after ratio was changed-------');
//             await printBalances();
//         });
//         it('claim yields and then withdrawal', async () => {
//             await ce_vault.claimYields(staker_1, { from: staker_1 });
//             tx = await ce_vault.withdrawal(
//                 staker_1,
//                 (await ce_token.balanceOf(staker_1)).toString(),
//                 { from: staker_1 }
//             );
//             console.log(`withdrawn: ${tx.logs['0'].args.value.toString()}`);
//             console.log('-------balance after withdrawal full-------');
//             await printBalances();
//         });
//     });
// });