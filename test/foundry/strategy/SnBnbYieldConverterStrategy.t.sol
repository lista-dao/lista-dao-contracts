// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../../contracts/amo/DynamicDutyCalculator.sol";
import "../../../contracts/Interaction.sol";
import "../../../contracts/LisUSD.sol";
import "../../../contracts/oracle/ResilientOracle.sol";
import "../../../contracts/strategy/SnBnbYieldConverterStrategy.sol";


contract SnBnbYieldConverterStrategyTest is Test {
    uint256 mainnet;

    ISnBnbStakeManager stakeManager;

    SnBnbYieldConverterStrategy strategy;

    function setUp() public {
        mainnet = vm.createSelectFork("https://bsc-dataseed.binance.org");

        ProxyAdmin proxyAdmin = ProxyAdmin(address(0x1Fa3E4718168077975fF4039304CC2e19Ae58c4C));
        SnBnbYieldConverterStrategy impl = new SnBnbYieldConverterStrategy();
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(payable(address(0x6F28FeC449dbd2056b76ac666350Af8773E03873)));

        vm.startPrank(address(0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253));
        proxyAdmin.upgrade(proxy, address(impl));
        vm.stopPrank();

        stakeManager = ISnBnbStakeManager(address(0x1adB950d8bB3dA4bE104211D5AB038628e477fE6));
        strategy = SnBnbYieldConverterStrategy(payable(address(0x6F28FeC449dbd2056b76ac666350Af8773E03873)));
    }

    function test_setUp() public {
//        vm.startPrank(address(0x91fC4BA20685339781888eCA3E9E1c12d40F0e13));
//        strategy.depositAll();
//        vm.stopPrank();

        console.log("balance", address(strategy).balance);
        console.log("bnbToDistribute", strategy.bnbToDistribute());

        uint256 _firstDistributeIdx = strategy._firstDistributeIdx();
        uint256 _nextWithdrawIdx = strategy._nextWithdrawIdx();
        console.log("_firstDistributeIdx", _firstDistributeIdx);
        console.log("_nextWithdrawIdx", _nextWithdrawIdx);
        console.log("snBnbToUnstake", strategy.snBnbToUnstake());


        uint256 sum = 0;
        for (uint256 i = _firstDistributeIdx; i < _nextWithdrawIdx; i++) {
            (,uint256 amount,,) = strategy._withdrawRequests(i);
            sum += amount;
            console.log("loop sum", i, amount, sum);
        }

        console.log("sum", sum, sum / 1 ether);

//        console.log("bnbDepositBalance", strategy.bnbDepositBalance() / 1 ether);
//        console.log("snBnbToUnstake", strategy.snBnbToUnstake() / 1 ether);
//        console.log("bnbToDistribute", strategy.bnbToDistribute() / 1 ether);
//
//        console.log("bnb balance", address(strategy).balance);
    }

    function test_withdraw() public {
        ISnBnbStakeManager.WithdrawalRequest[] memory requests = stakeManager
            .getUserWithdrawalRequests(address(strategy));

        uint256 total = 0;
        for (uint256 times = 0; times < requests.length; times++) {
            (bool isClaimable, uint256 amount) = stakeManager
                .getUserRequestStatus(address(strategy), times);

            console.log("loop", times, amount, amount / 1 ether);
            total += amount;
        }

        console.log("total", total, total / 1 ether);

//        uint256 snAmount0 = stakeManager.convertBnbToSnBnb(1 ether);
//        uint256 snAmount1 = stakeManager.convertBnbToSnBnb(1 ether);
//        console.log("SnBnb sum", snAmount0 + snAmount1);
//        console.log("convertSnBnbToBnb sum", stakeManager.convertSnBnbToBnb(snAmount0 + snAmount1));
//        console.log("convertSnBnbToBnb sum", stakeManager.convertSnBnbToBnb(snAmount0 + snAmount1));

//        console.log("convertBnbToSnBnb", snAmount0);
//        console.log("convertSnBnbToBnb", stakeManager.convertSnBnbToBnb(snAmount0));
//        console.log("convertSnBnbToBnb added", snAmount0 + 1 wei);
//        console.log("convertSnBnbToBnb fixed", stakeManager.convertSnBnbToBnb(snAmount0 + 1 wei));
    }
}
