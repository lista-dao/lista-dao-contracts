// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../../contracts/ceros/ETH/CeETHVault.sol";
import "../../../contracts/ceros/ETH/CerosETHRouter.sol";
import "../../../contracts/ceros/ETH/HelioETHProvider.sol";

contract CeETHVaultTest is Test {
    address public referral = address(0x1A11AA);
    address public proxyAdminOwner = address(0x2A11AA);
    address public provider = address(0x3A11AA);
    address public vaultTokenOwner = 0x702115D6d3Bbb37F407aae4dEcf9d09980e28ebc;

    uint256 mainnet;

    CerosETHRouter cerosETHRouter;

    CeETHVault ceETHVault;
    // ETH
    ICertToken certToken;

    ICertToken ceToken;
    // wBETH
    IBETH wBETH;

    IUnwrapETH unwrapETH;

    address strategyBot;

    function setUp() public {
        // at 41693651, 32.34 ETH in unwrapETH
        mainnet = vm.createSelectFork("https://bsc-dataseed.binance.org");
        certToken = ICertToken(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
        ceToken = ICertToken(0x6C813D1d114d0caBf3F82f9E910BC29fE7f96451);
        wBETH = IBETH(0xa2E3356610840701BDf5611a53974510Ae27E2e1);
        unwrapETH = IUnwrapETH(0x79973d557CD9dd87eb61E250cc2572c990e20196);
        strategyBot = msg.sender;

        // vault part
        CeETHVault ceETHVaultImpl = new CeETHVault();
        TransparentUpgradeableProxy ceETHVaultProxy = new TransparentUpgradeableProxy(
            address(ceETHVaultImpl),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(string,address,address,address,uint256,address)",
                "CEROS wBETH Vault", address(certToken), address(ceToken), address(wBETH), 1000000000000000, strategyBot // last one is bot
            )
        );

        ceETHVault = CeETHVault(address(ceETHVaultProxy));

        assertEq(address(wBETH), address(ceETHVault.getBETHAddress()));
        assertEq(strategyBot, address(ceETHVault.getStrategist()));
        assertEq(strategyBot, ceETHVault.getStrategist());

        // router part
        CerosETHRouter cerosETHRouterImpl = new CerosETHRouter();
        TransparentUpgradeableProxy cerosETHRouterProxy = new TransparentUpgradeableProxy(
            address(cerosETHRouterImpl),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,uint256,address,uint256)",
                address(certToken), address(ceToken), address(wBETH), address(ceETHVaultProxy), 1e17, referral, 0
            )
        );
        cerosETHRouter = CerosETHRouter(address(cerosETHRouterProxy));
        assertEq(address(ceETHVault), address(cerosETHRouter.getVaultAddress()));
        cerosETHRouter.changeProvider(provider);
        assertEq(provider, address(cerosETHRouter.getProvider()));
        cerosETHRouter.changeCertTokenRatio(0);
        assertEq(0, cerosETHRouter.getCertTokenRatio());

        vm.startPrank(vaultTokenOwner);
        address(ceToken).call(abi.encodeWithSignature("changeVault(address)", address(ceETHVault)));
        vm.stopPrank();
        assertEq(address(ceETHVault), ICeToken(address(ceToken)).getVaultAddress());

        ceETHVault.changeRouter(address(cerosETHRouterProxy));
        assertEq(address(cerosETHRouterProxy), ceETHVault.getRouter());

        ceETHVault.changeUnwrapEthAddress(address(unwrapETH));
        assertEq(address(unwrapETH), ceETHVault.getUnwrapEthAddress());

        ceETHVault.changeBatchWithdrawBufferedAmount(1e17);
        assertEq(1e17, ceETHVault._batchWithdrawBufferedAmount());
    }

    function test_ethVault_setup() public {
        assertEq(address(wBETH), address(ceETHVault.getBETHAddress()));
        assertEq(address(ceETHVault), address(cerosETHRouter.getVaultAddress()));
    }

    function test_ethVault_deposit() public {
        deal(address(certToken), provider, 1e18);
        assertEq(0, ceETHVault.getTotalBETHAmountInVault());
        assertEq(0, ceETHVault.getTotalETHAmountInVault());

        vm.startPrank(provider);
        IERC20(address(certToken)).approve(address(cerosETHRouter), type(uint256).max);
        cerosETHRouter.deposit(1e18);
        vm.stopPrank();

        assertEq(1e18 * 1e18 / wBETH.exchangeRate(), ceETHVault.getTotalBETHAmountInVault());
        assertEq(0, ceETHVault.getTotalETHAmountInVault());
        assertEq((1e18 * 1e18 / wBETH.exchangeRate()) * wBETH.exchangeRate() / 1e18
            , ceETHVault.getCeTokenBalanceOf(address(cerosETHRouter)));
    }

    /**
    * request a new withdraw
    */
    function test_ethVault_withdraw() public {
        address recipient = makeAddr("withdraw_user_0");
        deal(address(certToken), provider, 10e18);

        assertEq(0, IERC20(certToken).balanceOf(recipient));
        CeETHVault.UserWithdrawRequest[] memory beforeRequests = ceETHVault.getUserWithdrawRequests(recipient);
        assertEq(0, beforeRequests.length);

        vm.startPrank(provider);
        IERC20(address(certToken)).approve(address(cerosETHRouter), type(uint256).max);
        cerosETHRouter.deposit(10e18);
        vm.stopPrank();

        vm.startPrank(address(cerosETHRouter));
        uint256 actual = ceETHVault.withdrawETHFor(provider, recipient, 1e18);
        vm.stopPrank();

        console.log(actual);
        assertEq(0, IERC20(certToken).balanceOf(recipient));
        assertEq(1e18 - (1e18 * ceETHVault.getWithdrawalFee() / 1e18), actual);
        assertEq(1e18, ceETHVault._nextBatchEthAmount());
        assertEq(1e18, ceETHVault._needEthAmount());

        CeETHVault.UserWithdrawRequest[] memory afterRequests = ceETHVault.getUserWithdrawRequests(recipient);
        assertEq(1, afterRequests.length);
        assertEq(0, afterRequests[0].userRequestIndex);
        assertEq(recipient, afterRequests[0].recipient);
        assertEq(1e18, afterRequests[0].ethAmount);
        assertEq(1e18 * ceETHVault.getWithdrawalFee() / 1e18, afterRequests[0].feeAmount);
    }

    /**
    * request 2 new withdraws
    */
    function test_ethVault_withdraw2() public {
        address recipient = makeAddr("withdraw_user_0");
        deal(address(certToken), provider, 10e18);

        assertEq(0, IERC20(certToken).balanceOf(recipient));
        CeETHVault.UserWithdrawRequest[] memory beforeRequests = ceETHVault.getUserWithdrawRequests(recipient);
        assertEq(0, beforeRequests.length);

        vm.startPrank(provider);
        IERC20(address(certToken)).approve(address(cerosETHRouter), type(uint256).max);
        cerosETHRouter.deposit(10e18);
        vm.stopPrank();

        vm.startPrank(address(cerosETHRouter));
        uint256 actual0 = ceETHVault.withdrawETHFor(provider, recipient, 1e18);
        uint256 actual1 = ceETHVault.withdrawETHFor(provider, recipient, 2e18);
        vm.stopPrank();

        assertEq(0, IERC20(certToken).balanceOf(recipient));
        assertEq(2e18 - (2e18 * ceETHVault.getWithdrawalFee() / 1e18), actual1);

        CeETHVault.UserWithdrawRequest[] memory allRequests = ceETHVault.getWithdrawRequests(0);
        assertEq(2, allRequests.length);

        CeETHVault.UserWithdrawRequest[] memory afterRequests = ceETHVault.getUserWithdrawRequests(recipient);
        assertEq(2, afterRequests.length);
        assertEq(0, afterRequests[0].userRequestIndex);
        assertEq(recipient, afterRequests[0].recipient);
        assertEq(1e18, afterRequests[0].ethAmount);
        assertEq(1, afterRequests[1].userRequestIndex);
        assertEq(recipient, afterRequests[1].recipient);
        assertEq(2e18, afterRequests[1].ethAmount);
        assertEq(2e18 * ceETHVault.getWithdrawalFee() / 1e18, afterRequests[1].feeAmount);
    }

    function test_ethVault_batchWithdraw_empty() public {
        vm.startPrank(strategyBot);
        vm.expectRevert("no batch eth amount");
        ceETHVault.batchWithdraw();
        vm.stopPrank();
    }

    function test_ethVault_batchWithdraw_acl() public {
        address recipient0 = makeAddr("withdraw_user_0");

        vm.startPrank(recipient0);
        vm.expectRevert("Router: not allowed");
        ceETHVault.batchWithdraw();
        vm.stopPrank();
    }

    function test_ethVault_batchWithdraw_ok() public {
        address recipient0 = makeAddr("withdraw_user_0");
        address recipient1 = makeAddr("withdraw_user_1");
        deal(address(certToken), provider, 10e18);

        vm.startPrank(provider);
        IERC20(address(certToken)).approve(address(cerosETHRouter), type(uint256).max);
        cerosETHRouter.deposit(10e18);
        vm.stopPrank();

        vm.startPrank(address(cerosETHRouter));
        uint256 actual0 = ceETHVault.withdrawETHFor(provider, recipient0, 1e18);
        uint256 actual1 = ceETHVault.withdrawETHFor(provider, recipient1, 2e18);
        vm.stopPrank();

        IUnwrapETH.WithdrawRequest[] memory beforeUnwrapRequests = unwrapETH.getUserWithdrawRequests(address(ceETHVault));
        assertEq(0, beforeUnwrapRequests.length);

        vm.startPrank(strategyBot);
        ceETHVault.batchWithdraw();
        vm.stopPrank();

        assertEq(0, ceETHVault._nextBatchEthAmount());
        assertEq(block.timestamp, ceETHVault._lastBatchWithdrawTime());
        IUnwrapETH.WithdrawRequest[] memory afterUnwrapRequests = unwrapETH.getUserWithdrawRequests(address(ceETHVault));
        assertEq(1, afterUnwrapRequests.length);
        // 31e17 = 1e18 + 2e18 + 1e17(buffer)
        assertEq(31e17 * 1e18 / wBETH.exchangeRate(), afterUnwrapRequests[0].wbethAmount);
    }

    function test_ethVault_batchWithdraw_reentrant() public {
        test_ethVault_batchWithdraw_ok();

        address recipient0 = makeAddr("withdraw_user_0");
        address recipient1 = makeAddr("withdraw_user_1");
        vm.startPrank(address(cerosETHRouter));
        uint256 actual0 = ceETHVault.withdrawETHFor(provider, recipient0, 1e18);
        uint256 actual1 = ceETHVault.withdrawETHFor(provider, recipient1, 2e18);
        vm.stopPrank();

        vm.startPrank(strategyBot);
        vm.expectRevert("allow only once a day");
        ceETHVault.batchWithdraw();
        vm.stopPrank();
    }

    function test_ethVault_claimUnwrapETHWithraw_empty() public {
        vm.startPrank(strategyBot);
        vm.expectRevert("Invalid index");
        ceETHVault.claimUnwrapETHWithraw(0);
        vm.stopPrank();
    }

    function test_ethVault_claimUnwrapETHWithraw_time_not_met() public {
        uint256 index = ITestUnWrapETH(address(unwrapETH)).nextIndex();
        test_ethVault_batchWithdraw_ok();

        IUnwrapETH.WithdrawRequest[] memory afterUnwrapRequests = unwrapETH.getUserWithdrawRequests(address(ceETHVault));
        assertEq(1, afterUnwrapRequests.length);

        vm.startPrank(strategyBot);
        vm.expectRevert("Claim time not reach");
        ceETHVault.claimUnwrapETHWithraw(0);
        vm.stopPrank();
    }

    function test_ethVault_claimUnwrapETHWithraw_ok() public {
        uint256 index = ITestUnWrapETH(address(unwrapETH)).nextIndex();
        test_ethVault_batchWithdraw_ok();

        IUnwrapETH.WithdrawRequest[] memory afterUnwrapRequests = unwrapETH.getUserWithdrawRequests(address(ceETHVault));
        assertEq(1, afterUnwrapRequests.length);

        skip(7 days);

        uint256 beforeEthAmount = ceETHVault.getTotalETHAmountInVault();
        assertEq(0, beforeEthAmount);

        vm.startPrank(strategyBot);
        uint256 actual = ceETHVault.claimUnwrapETHWithraw(0);
        vm.stopPrank();

        assertEq((31e17 * 1e18 / wBETH.exchangeRate()) * wBETH.exchangeRate() / 1e18, actual);

        uint256 afterEthAmount = ceETHVault.getTotalETHAmountInVault();
        assertEq((31e17 * 1e18 / wBETH.exchangeRate()) * wBETH.exchangeRate() / 1e18, afterEthAmount);
    }

    function test_ethVault_distributeETH_empty() public {
        vm.startPrank(strategyBot);
        vm.expectRevert("no withdraw to distribute");
        ceETHVault.distributeETH(100);
        vm.stopPrank();
    }

    function test_ethVault_distributeETH_no_balance() public {
        test_ethVault_withdraw();

        vm.startPrank(strategyBot);
        vm.expectRevert("no need or no available eth to distribute");
        ceETHVault.distributeETH(100);
        vm.stopPrank();
    }

    function test_ethVault_distributeETH_ok() public {
        address recipient = makeAddr("withdraw_user_0");

        // 2 withdraw: [1:1e18, 2:1e18]
        test_ethVault_withdraw2();
        deal(address(certToken), address(ceETHVault), 2e18);

        vm.startPrank(strategyBot);
        uint256 actual = ceETHVault.distributeETH(100);
        vm.stopPrank();

        assertEq(1, actual);
        assertEq(1e18 - (1e18 * ceETHVault.getWithdrawalFee() / 1e18), IERC20(certToken).balanceOf(recipient));
    }

    function test_ethVault_distributeETH_ok_multi() public {
        address recipient = makeAddr("withdraw_user_0");

        // 2 withdraw: [1:1e18, 2:1e18]
        test_ethVault_withdraw2();
        deal(address(certToken), address(ceETHVault), 4e18);

        vm.startPrank(strategyBot);
        uint256 actual = ceETHVault.distributeETH(100);
        vm.stopPrank();

        assertEq(2, actual);
        assertEq(3e18 - (3e18 * ceETHVault.getWithdrawalFee() / 1e18), IERC20(certToken).balanceOf(recipient));
    }
}

interface ICeToken is ICertToken {
    function changeVault(address vault) external;

    function getVaultAddress() external view returns (address);
}

interface ITestUnWrapETH is IUnwrapETH {
    function nextIndex() external view returns (uint256);
}
