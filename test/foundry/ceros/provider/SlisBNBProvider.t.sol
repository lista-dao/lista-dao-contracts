// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../../../contracts/interfaces/VatLike.sol";
import "../../../../contracts/ceros/ClisToken.sol";
import "../../../../contracts/ceros/clisBNB.sol";
import "../../../../contracts/ceros/provider/SlisBNBLpProvider.sol";


contract SlisBNBLpProviderTest is Test {
    address admin = address(0x1A11AA);
    address manager = address(0x2A11AA);
    address user = address(0x3A11AA);
    address recipient = address(0x4A11AA);
    address delegateTo = address(0x5A11AA);
    address reserveAddress = address(0x6A11AA);
    address delegateTo1 = address(0x7A11AA);
    address proxyAdminOwner = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;

    address sender;

    uint256 mainnet;

    IDao interaction;

    VatLike vat;

    bytes32 slisBNBIlk;

    IERC20 slisBnb;

    clisBNB clisBnb;

    SlisBNBLpProvider slisBNBLpProvider;

    function setUp() public {
        sender = msg.sender;
        mainnet = vm.createSelectFork("https://bsc-dataseed.binance.org");

        vat = VatLike(0x33A34eAB3ee892D40420507B820347b1cA2201c4);
        interaction = IDao(0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4);
        slisBnb = IERC20(0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B);
        clisBnb = clisBNB(0x4b30fcAA7945fE9fDEFD2895aae539ba102Ed6F6);

        TransparentUpgradeableProxy providerProxy = new TransparentUpgradeableProxy(
            address(new SlisBNBLpProvider()),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address,uint128)",
                address(clisBnb), address(slisBnb), address(interaction), reserveAddress, address(interaction), address(admin), 9e17
            )
        );
        slisBNBLpProvider = SlisBNBLpProvider(address(providerProxy));
//        slisBNBLpProvider.changeProxy(address(interaction));
        slisBNBLpProvider.transferOwnership(admin);

        vm.startPrank(address(0x702115D6d3Bbb37F407aae4dEcf9d09980e28ebc));
        clisBnb.changeMinter(address(slisBNBLpProvider));
        vm.stopPrank();

        vm.startPrank(proxyAdminOwner);
        interaction.setHelioProvider(address(slisBnb), address(slisBNBLpProvider));
        vm.stopPrank();

        (, bytes32 ilk, ,) = interaction.collaterals(address(slisBnb));
        slisBNBIlk = ilk;
    }

    function test_setUp() public {
        assertEq(admin, slisBNBLpProvider.owner());
        assertEq(address(interaction), slisBNBLpProvider._proxy());

        assertEq(address(slisBNBLpProvider), clisBnb.getMinter());
    }

    function test_provide() public {
        deal(address(slisBnb), user, 123e18);

        vm.startPrank(user);
        slisBnb.approve(address(slisBNBLpProvider), 121e18);
        uint256 actual = slisBNBLpProvider.provide(121e18);
        vm.stopPrank();

        uint256 userExpect = 121e18 * 9e17 / 1e18;

        assertEq(userExpect, actual);
        assertEq(2e18, slisBnb.balanceOf(user));
        assertEq(userExpect, clisBnb.balanceOf(user));
        assertEq(121e18 - userExpect, clisBnb.balanceOf(reserveAddress));
        assertEq(121e18 - userExpect, slisBNBLpProvider._userReservedAmount(user));

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(121e18, deposit);
    }

    function test_provide_delegate() public {
        deal(address(slisBnb), user, 123e18);

        vm.startPrank(user);
        slisBnb.approve(address(slisBNBLpProvider), 121e18);
        uint256 actual = slisBNBLpProvider.provide(121e18, delegateTo);
        vm.stopPrank();

        uint256 userExpect = 121e18 * 9e17 / 1e18;

        assertEq(userExpect, actual);
        assertEq(2e18, slisBnb.balanceOf(user));
        assertEq(userExpect, clisBnb.balanceOf(delegateTo));
        assertEq(121e18 - userExpect, clisBnb.balanceOf(reserveAddress));
        assertEq(121e18 - userExpect, slisBNBLpProvider._userReservedAmount(user));

        (address actualTo, uint256 amount) = slisBNBLpProvider._delegation(user);
        assertEq(userExpect, amount);
        assertEq(delegateTo, actualTo);

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(121e18, deposit);
    }

    function test_delegateAllTo_new() public {
        test_provide();

        vm.startPrank(user);
        slisBNBLpProvider.delegateAllTo(delegateTo);
        vm.stopPrank();

        uint256 userExpect = 121e18 * 9e17 / 1e18;
        assertEq(2e18, slisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(user));
        assertEq(userExpect, clisBnb.balanceOf(delegateTo));
        assertEq(121e18 - userExpect, clisBnb.balanceOf(reserveAddress));
        assertEq(121e18 - userExpect, slisBNBLpProvider._userReservedAmount(user));

        (address actualTo, uint256 amount) = slisBNBLpProvider._delegation(user);
        assertEq(userExpect, amount);
        assertEq(delegateTo, actualTo);

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(121e18, deposit);
    }

    function test_delegateAllTo_change() public {
        test_provide_delegate();

        vm.startPrank(user);
        slisBNBLpProvider.delegateAllTo(delegateTo1);
        vm.stopPrank();

        uint256 userExpect = 121e18 * 9e17 / 1e18;

        assertEq(0, clisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(delegateTo));
        assertEq(userExpect, clisBnb.balanceOf(delegateTo1));
        assertEq(121e18 - userExpect, clisBnb.balanceOf(reserveAddress));
        assertEq(121e18 - userExpect, slisBNBLpProvider._userReservedAmount(user));

        (address actualTo, uint256 amount) = slisBNBLpProvider._delegation(user);
        assertEq(userExpect, amount);
        assertEq(delegateTo1, actualTo);

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(121e18, deposit);
    }

    function test_delegateAllTo_toSelf() public {
        test_provide_delegate();

        vm.startPrank(user);
        slisBNBLpProvider.delegateAllTo(user);
        vm.stopPrank();

        uint256 userExpect = 121e18 * 9e17 / 1e18;

        assertEq(0, clisBnb.balanceOf(delegateTo));
        assertEq(userExpect, clisBnb.balanceOf(user));
        assertEq(121e18 - userExpect, clisBnb.balanceOf(reserveAddress));
        assertEq(121e18 - userExpect, slisBNBLpProvider._userReservedAmount(user));

        (address actualTo, uint256 amount) = slisBNBLpProvider._delegation(user);
        assertEq(0, amount);
        assertEq(address(0), actualTo);

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(121e18, deposit);
    }

    function test_provide_not_enough_balance() public {
        deal(address(slisBnb), user, 20e18);

        vm.startPrank(user);
        slisBnb.approve(address(slisBNBLpProvider), 121e18);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        uint256 actual = slisBNBLpProvider.provide(121e18, delegateTo);
        vm.stopPrank();
    }

    function test_release_full() public {
        test_provide();

        vm.startPrank(user);
        uint256 actual = slisBNBLpProvider.release(user, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(123e18, slisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(reserveAddress));
        assertEq(0, slisBNBLpProvider._userReservedAmount(user));

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(0, deposit);
    }

    function test_release_full_delegate() public {
        test_provide_delegate();

        vm.startPrank(user);
        uint256 actual = slisBNBLpProvider.release(user, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(123e18, slisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(delegateTo));
        assertEq(0, clisBnb.balanceOf(reserveAddress));
        assertEq(0, slisBNBLpProvider._userReservedAmount(user));

        (address actualTo, uint256 amount) = slisBNBLpProvider._delegation(user);
        assertEq(delegateTo, actualTo);
        assertEq(0, amount);

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(0, deposit);
    }

    function test_release_full_recipient() public {
        test_provide();

        vm.startPrank(user);
        uint256 actual = slisBNBLpProvider.release(recipient, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(2e18, slisBnb.balanceOf(user));
        assertEq(121e18, slisBnb.balanceOf(recipient));
        assertEq(0, clisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(reserveAddress));
        assertEq(0, slisBNBLpProvider._userReservedAmount(user));

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(0, deposit);
    }

    function test_release_partial() public {
        test_provide();

        vm.startPrank(user);
        uint256 actual = slisBNBLpProvider.release(user, 21e18);
        vm.stopPrank();

        uint256 userExpect = 100e18 * 9e17 / 1e18;
        assertEq(21e18, actual);
        assertEq(23e18, slisBnb.balanceOf(user));
        assertEq(userExpect, clisBnb.balanceOf(user));
        assertEq(100e18 - userExpect, clisBnb.balanceOf(reserveAddress));
        assertEq(100e18 - userExpect, slisBNBLpProvider._userReservedAmount(user));

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(100e18, deposit);
    }

    function test_release_partial_delegated() public {
        test_provide_delegate();

        vm.startPrank(user);
        uint256 actual = slisBNBLpProvider.release(user, 21e18);
        vm.stopPrank();

        uint256 userExpect = 100e18 * 9e17 / 1e18;
        assertEq(21e18, actual);
        assertEq(23e18, slisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(user));
        assertEq(userExpect, clisBnb.balanceOf(delegateTo));
        assertEq(100e18 - userExpect, clisBnb.balanceOf(reserveAddress));
        assertEq(100e18 - userExpect, slisBNBLpProvider._userReservedAmount(user));

        (address actualTo, uint256 amount) = slisBNBLpProvider._delegation(user);
        assertEq(delegateTo, actualTo);
        assertEq(userExpect, amount);

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(100e18, deposit);
    }

    function test_release_delegatee_mixed() public {
        // set up delegateTo's tokens
        deal(address(slisBnb), delegateTo, 123e18);
        console.log("part 0 ok");

        vm.startPrank(delegateTo);
        slisBnb.approve(address(slisBNBLpProvider), 121e18);
        slisBNBLpProvider.provide(121e18);
        vm.stopPrank();

        uint256 delegateExpect = 121e18 * 9e17 / 1e18;
        uint256 delegateReserve = 121e18 - delegateExpect;
        assertEq(2e18, slisBnb.balanceOf(delegateTo));
        assertEq(delegateExpect, clisBnb.balanceOf(delegateTo));
        assertEq(delegateReserve, slisBNBLpProvider._userReservedAmount(delegateTo));
        (uint256 delegateToDeposit, ) = vat.urns(slisBNBIlk, delegateTo);
        assertEq(121e18, delegateToDeposit);

        // clear delegateTo collateral tokens, make it like an old user
        deal(address(clisBnb), delegateTo, 0);
        console.log("part 1 ok");

        // set up user's tokens
        deal(address(slisBnb), user, 345e18);

        vm.startPrank(user);
        slisBnb.approve(address(slisBNBLpProvider), 345e18);
        slisBNBLpProvider.provide(345e18, delegateTo);
        vm.stopPrank();

        uint256 userExpect = 345e18 * 9e17 / 1e18;
        assertEq(0, slisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(user));
        assertEq(userExpect, clisBnb.balanceOf(delegateTo));
//        assertEq(345e18 - userExpect, clisBnb.balanceOf(reserveAddress));
        assertEq(345e18 - userExpect, slisBNBLpProvider._userReservedAmount(user));

        (uint256 deposit, ) = vat.urns(slisBNBIlk, user);
        assertEq(345e18, deposit);
        console.log("part 2 ok");

        // user withdraw partially
        vm.startPrank(user);
        slisBNBLpProvider.release(user, 11e18);
        vm.stopPrank();

        uint256 userExpect1 = (345e18 - 11e18) * 9e17 / 1e18;
        assertEq(11e18, slisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(user));
        assertEq(userExpect1, clisBnb.balanceOf(delegateTo));
//        assertEq(345e18 - 11e18 - userExpect1, clisBnb.balanceOf(reserveAddress));
        assertEq(345e18 - 11e18 - userExpect1, slisBNBLpProvider._userReservedAmount(user));

        (uint256 deposit1, ) = vat.urns(slisBNBIlk, user);
        assertEq(345e18 - 11e18, deposit1);
        console.log("part 3 ok");

        // delegateTo release should not burn delegatedAmount
        vm.startPrank(delegateTo);
        slisBNBLpProvider.release(delegateTo, 121e18);
        vm.stopPrank();

        assertEq(123e18, slisBnb.balanceOf(delegateTo));
        assertEq(userExpect1, clisBnb.balanceOf(delegateTo));

        (uint256 deposit2, ) = vat.urns(slisBNBIlk, delegateTo);
        assertEq(0, deposit2);
    }

    function test_daoBurn() public {
        test_provide();

        vm.startPrank(address(interaction));
        slisBNBLpProvider.daoBurn(user, 121e18);
        vm.stopPrank();

        assertEq(2e18, slisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(user));
        assertEq(0, slisBNBLpProvider._userReservedAmount(user));
    }

    function test_daoBurn_delegated() public {
        test_provide_delegate();

        vm.startPrank(address(interaction));
        slisBNBLpProvider.daoBurn(user, 121e18);
        vm.stopPrank();

        assertEq(0, clisBnb.balanceOf(user));
        assertEq(0, clisBnb.balanceOf(delegateTo));
        assertEq(0, slisBNBLpProvider._userReservedAmount(user));
    }

    function test_syncUserLp_exchangeRate_upper() public {
        deal(address(slisBnb), user, 1 ether);

        uint256 amount = 1 ether;
        uint256 receiverBalanceBefore = clisBnb.balanceOf(reserveAddress);

        vm.startPrank(user);
        slisBnb.approve(address(slisBNBLpProvider), amount);
        slisBNBLpProvider.provide(amount, delegateTo);
        vm.stopPrank();

        assertEq(interaction.locked(address(slisBnb), user), amount, "interaction.locked user");
        assertEq(clisBnb.balanceOf(reserveAddress) - receiverBalanceBefore, (1 ether - userCollateralRate) * amount * exchangeRate / 10 ** 36, "clisBnb.balanceOf reserveAddress");

        //userLpRate invalid
        //change exchange rate to 1.1 ether
        vm.startPrank(admin);
        slisBNBLpProvider.changeExchangeRate(1.1 ether);
        slisBNBLpProvider.syncUserLp(user);
        vm.stopPrank();

        uint128 tokenExchangeRate = 1.1 ether;
        assertEq(interaction.locked(address(slisBnb), user), amount, "interaction.locked user final");
        assertEq(clisBnb.balanceOf(reserveAddress) - receiverBalanceBefore, (1 ether - userCollateralRate) * amount * tokenExchangeRate / 10 ** 36, "clisBnb.balanceOf reserveAddress final");
    }
}
