// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../contracts/ceros/clisBNB.sol";
import "../../../contracts/ceros/stake/ytslisBNBStakeManager.sol";


contract ytslisBNBStakeManagerTest is Test {
    using SafeERC20 for IERC20;

    address user0 = address(0x1A11AA);
    address delegateTo = address(0x2A11AA);
    address delegateTo1 = address(0x3A11AA);
    address admin = address(0x4A11AA);
    address proxyAdminOwner = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
    address pauser = address(0x5A11AA);
    address manager = address(0x6A11AA);
    address reserveAddress = address(0x7A11AA);

    uint256 mainnet;

    IERC20 slisBNB;

    clisBNB clisBnb;

    ytslisBNBStakeManager stakeManager;

    uint128 exchangeRate = 1023e15;
    uint128 exchangeRate1 = 1031e15;

    uint128 userCollateralRate = 95e16;

    function setUp() public {
        mainnet = vm.createSelectFork("https://bsc-dataseed.binance.org");
        slisBNB = IERC20(0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B);
        clisBnb = clisBNB(0x4b30fcAA7945fE9fDEFD2895aae539ba102Ed6F6);

        TransparentUpgradeableProxy ytslisBNBStakeManagerProxy = new TransparentUpgradeableProxy(
            address(new ytslisBNBStakeManager()),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address,uint128,uint128)",
                admin, manager, pauser, address(slisBNB), address(clisBnb), reserveAddress, exchangeRate, userCollateralRate
            )
        );
        stakeManager = ytslisBNBStakeManager(address(ytslisBNBStakeManagerProxy));

        vm.startPrank(address(0x702115D6d3Bbb37F407aae4dEcf9d09980e28ebc));
        clisBnb.changeMinter(address(stakeManager));
        vm.stopPrank();
    }

    function test_setUp() public {
        assertEq(exchangeRate, stakeManager.exchangeRate());
        assertEq(address(slisBNB), stakeManager.certToken());
        assertEq(address(clisBnb), address(stakeManager.collateralToken()));
    }

    function test_stake() public {
        deal(address(slisBNB), user0, 123e18);

        vm.startPrank(user0);
        IERC20(slisBNB).safeApprove(address(stakeManager), 123e18);
        uint256 actual = stakeManager.stake(123e18);
        vm.stopPrank();

        uint256 allCollateral = 123e18 * exchangeRate / 1e18;
        uint256 expect = allCollateral * userCollateralRate / 1e18;

        assertEq(expect, actual);
        assertEq(0, slisBNB.balanceOf(user0));
        assertEq(123e18, slisBNB.balanceOf(address(stakeManager)));
        assertEq(123e18, stakeManager.balanceOf(user0));

        assertEq(expect, clisBnb.balanceOf(user0));
        assertEq(expect, stakeManager.userCollateral(user0));
        assertEq(allCollateral - expect, clisBnb.balanceOf(reserveAddress));
        assertEq(allCollateral - expect, stakeManager.userReservedCollateral(user0));
    }

    function test_stake_notEnough() public {
        deal(address(slisBNB), user0, 123e18);

        vm.startPrank(user0);
        IERC20(slisBNB).safeApprove(address(stakeManager), 200e18);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        uint256 actual = stakeManager.stake(200e18);
        vm.stopPrank();
    }

    function test_stake_delegate() public {
        deal(address(slisBNB), user0, 123e18);

        vm.startPrank(user0);
        IERC20(slisBNB).safeApprove(address(stakeManager), 123e18);
        uint256 actual = stakeManager.stake(123e18, delegateTo);
        vm.stopPrank();

        uint256 allCollateral = 123e18 * exchangeRate / 1e18;
        uint256 expect = allCollateral * userCollateralRate / 1e18;

        assertEq(expect, actual);
        assertEq(0, slisBNB.balanceOf(user0));
        assertEq(0, clisBnb.balanceOf(user0));
        assertEq(123e18, stakeManager.balanceOf(user0));

        assertEq(expect, clisBnb.balanceOf(delegateTo));
        assertEq(expect, stakeManager.userCollateral(user0));
        assertEq(allCollateral - expect, clisBnb.balanceOf(reserveAddress));
        assertEq(allCollateral - expect, stakeManager.userReservedCollateral(user0));
    }

    function test_delegateAllTo_new() public {
        test_stake();

        vm.startPrank(user0);
        stakeManager.delegateAllTo(delegateTo);
        vm.stopPrank();

        uint256 allCollateral = 123e18 * exchangeRate / 1e18;
        uint256 expect = allCollateral * userCollateralRate / 1e18;

        assertEq(0, slisBNB.balanceOf(user0));
        assertEq(0, clisBnb.balanceOf(user0));
        assertEq(123e18, stakeManager.balanceOf(user0));

        assertEq(expect, clisBnb.balanceOf(delegateTo));
        assertEq(expect, stakeManager.userCollateral(user0));
        assertEq(allCollateral - expect, stakeManager.userReservedCollateral(user0));
    }

    function test_delegateAllTo_change() public {
        test_stake_delegate();

        vm.startPrank(user0);
        stakeManager.delegateAllTo(delegateTo1);
        vm.stopPrank();

        uint256 allCollateral = 123e18 * exchangeRate / 1e18;
        uint256 expect = allCollateral * userCollateralRate / 1e18;

        assertEq(0, slisBNB.balanceOf(user0));
        assertEq(0, clisBnb.balanceOf(user0));
        assertEq(0, clisBnb.balanceOf(delegateTo));
        assertEq(123e18, stakeManager.balanceOf(user0));

        assertEq(expect, clisBnb.balanceOf(delegateTo1));
        assertEq(expect, stakeManager.userCollateral(user0));
        assertEq(allCollateral - expect, stakeManager.userReservedCollateral(user0));
    }

    function test_unstake() public {
        test_stake();

        vm.startPrank(user0);
        uint256 actual = stakeManager.unstake(123e18);
        vm.stopPrank();

        assertEq(123e18, actual);
        assertEq(123e18, slisBNB.balanceOf(user0));
        assertEq(0, stakeManager.balanceOf(user0));

        assertEq(0, slisBNB.balanceOf(address(stakeManager)));
        assertEq(0, clisBnb.balanceOf(user0));
        assertEq(0, clisBnb.balanceOf(reserveAddress));
        assertEq(0, stakeManager.userReservedCollateral(user0));
    }

    function test_unstake_partial() public {
        test_stake();

        vm.startPrank(user0);
        uint256 actual = stakeManager.unstake(523e17);
        vm.stopPrank();

        uint256 allCollateral = (123e18 - 523e17) * exchangeRate / 1e18;
        uint256 expect = allCollateral * userCollateralRate / 1e18;

        assertEq(523e17, actual);
        assertEq(523e17, slisBNB.balanceOf(user0));
        assertEq(123e18 - 523e17, stakeManager.balanceOf(user0));
        assertEq(123e18 - 523e17, slisBNB.balanceOf(address(stakeManager)));

        assertEq(expect, clisBnb.balanceOf(user0));
        assertEq(expect, stakeManager.userCollateral(user0));
        assertEq(allCollateral - expect, clisBnb.balanceOf(reserveAddress));
        assertEq(allCollateral - expect, stakeManager.userReservedCollateral(user0));
    }

    function test_unstake_delegate() public {
        test_stake_delegate();

        vm.startPrank(user0);
        uint256 actual = stakeManager.unstake(123e18);
        vm.stopPrank();

        assertEq(123e18, actual);
        assertEq(123e18, slisBNB.balanceOf(user0));
        assertEq(0, stakeManager.balanceOf(user0));

        assertEq(0, slisBNB.balanceOf(address(stakeManager)));
        assertEq(0, clisBnb.balanceOf(user0));
        assertEq(0, clisBnb.balanceOf(delegateTo));
        assertEq(0, clisBnb.balanceOf(reserveAddress));
        assertEq(0, stakeManager.userReservedCollateral(user0));
    }

    function test_unstake_overflow() public {
        test_stake();

        vm.startPrank(user0);
        vm.expectRevert("insufficient balance");
        stakeManager.unstake(200e18);
        vm.stopPrank();
    }

    function test_isUserCollateralSynced_true() public {
        test_stake();

        bool actual = stakeManager.isUserCollateralSynced(user0);
        assertEq(true, actual);
    }

    function test_isUserCollateralSynced_false() public {
        test_stake();

        vm.startPrank(admin);
        stakeManager.changeExchangeRate(exchangeRate1);
        vm.stopPrank();

        bool actual = stakeManager.isUserCollateralSynced(user0);
        assertEq(false, actual);
        assertEq(exchangeRate1, stakeManager.exchangeRate());
    }

    function test_syncUserCollateral() public {
        test_stake();

        vm.startPrank(admin);
        stakeManager.changeExchangeRate(exchangeRate1);
        vm.stopPrank();

        vm.startPrank(manager);
        stakeManager.syncUserCollateral(user0);
        vm.stopPrank();

        assertEq(123e18, stakeManager.balanceOf(user0));

        uint256 allCollateral = 123e18 * exchangeRate1 / 1e18;
        uint256 expect = allCollateral * userCollateralRate / 1e18;

        assertEq(expect, clisBnb.balanceOf(user0));
        assertEq(expect, stakeManager.userCollateral(user0));
        assertEq(allCollateral - expect, clisBnb.balanceOf(reserveAddress));
        assertEq(allCollateral - expect, stakeManager.userReservedCollateral(user0));
    }
}
