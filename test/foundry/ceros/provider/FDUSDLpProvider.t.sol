// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../../../contracts/interfaces/VatLike.sol";
import "../../../../contracts/ceros/ClisToken.sol";
import "../../../../contracts/ceros/provider/FDUSDLpProvider.sol";


contract FDUSDLpProviderTest is Test {
    address admin = address(0x1A11AA);
    address manager = address(0x2A11AA);
    address user = address(0x3A11AA);
    address recipient = address(0x4A11AA);
    address delegateTo = address(0x5A11AA);
    address delegateTo1 = address(0x6A11AA);
    address proxyAdminOwner = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;

    address sender;

    uint256 mainnet;

    IDao interaction;

    VatLike vat;

    bytes32 fdusdIlk;

    IERC20 FDUSD;

    ClisToken clisFDUSD;

    FDUSDLpProvider fdusdLpProvider;

    function setUp() public {
        sender = msg.sender;
        mainnet = vm.createSelectFork("https://bsc-dataseed.binance.org");

        vat = VatLike(0x33A34eAB3ee892D40420507B820347b1cA2201c4);
        interaction = IDao(0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4);
        FDUSD = IERC20(0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409);

        TransparentUpgradeableProxy clisFDUSDProxy = new TransparentUpgradeableProxy(
            address(new ClisToken()),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(string,string)",
                "clisFDUSD", "clisFDUSD"
            )
        );
        clisFDUSD = ClisToken(address(clisFDUSDProxy));
        clisFDUSD.transferOwnership(admin);

        TransparentUpgradeableProxy providerProxy = new TransparentUpgradeableProxy(
            address(new FDUSDLpProvider()),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address)",
                address(clisFDUSD), address(FDUSD), address(interaction), address(interaction), admin
            )
        );
        fdusdLpProvider = FDUSDLpProvider(address(providerProxy));
        fdusdLpProvider.transferOwnership(admin);

        vm.startPrank(admin);
        clisFDUSD.addMinter(address(fdusdLpProvider));
        vm.stopPrank();

        vm.startPrank(proxyAdminOwner);
        interaction.setHelioProvider(address(FDUSD), address(fdusdLpProvider));
        vm.stopPrank();

        (, bytes32 ilk, ,) = interaction.collaterals(address(FDUSD));
        fdusdIlk = ilk;
    }

    function test_setUp() public {
        assertEq(admin, fdusdLpProvider.owner());
        assertEq(address(interaction), fdusdLpProvider._proxy());

        assertEq(admin, clisFDUSD.owner());
        assertEq(true, clisFDUSD._minters(address(fdusdLpProvider)));
    }

    function test_provide() public {
        deal(address(FDUSD), user, 123e18);

        vm.startPrank(user);
        FDUSD.approve(address(fdusdLpProvider), 121e18);
        uint256 actual = fdusdLpProvider.provide(121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(2e18, FDUSD.balanceOf(user));
        assertEq(121e18, clisFDUSD.balanceOf(user));

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(121e18, deposit);
    }

    function test_provide_delegate() public {
        deal(address(FDUSD), user, 123e18);

        vm.startPrank(user);
        FDUSD.approve(address(fdusdLpProvider), 121e18);
        uint256 actual = fdusdLpProvider.provide(121e18, delegateTo);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(2e18, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(121e18, clisFDUSD.balanceOf(delegateTo));

        (address actualTo, uint256 amount) = fdusdLpProvider._delegation(user);
        assertEq(121e18, amount);
        assertEq(delegateTo, actualTo);

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(121e18, deposit);
    }

    function test_delegateAllTo_new() public {
        test_provide();

        vm.startPrank(user);
        fdusdLpProvider.delegateAllTo(delegateTo);
        vm.stopPrank();

        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(121e18, clisFDUSD.balanceOf(delegateTo));

        (address actualTo, uint256 amount) = fdusdLpProvider._delegation(user);
        assertEq(121e18, amount);
        assertEq(delegateTo, actualTo);

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(121e18, deposit);
    }

    function test_delegateAllTo_change() public {
        test_provide_delegate();

        vm.startPrank(user);
        fdusdLpProvider.delegateAllTo(delegateTo1);
        vm.stopPrank();

        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(delegateTo));
        assertEq(121e18, clisFDUSD.balanceOf(delegateTo1));

        (address actualTo, uint256 amount) = fdusdLpProvider._delegation(user);
        assertEq(121e18, amount);
        assertEq(delegateTo1, actualTo);


        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(121e18, deposit);
    }

    function test_delegateAllTo_toSelf() public {
        test_provide_delegate();

        vm.startPrank(user);
        fdusdLpProvider.delegateAllTo(user);
        vm.stopPrank();

        assertEq(121e18, clisFDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(delegateTo));

        (address actualTo, uint256 amount) = fdusdLpProvider._delegation(user);
        assertEq(0, amount);
        assertEq(address(0), actualTo);

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(121e18, deposit);
    }

    function test_provide_not_enough_balance() public {
        deal(address(FDUSD), user, 21e18);

        vm.startPrank(user);
        FDUSD.approve(address(fdusdLpProvider), 121e18);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        uint256 actual = fdusdLpProvider.provide(121e18);
        vm.stopPrank();
    }

    function test_release_full() public {
        test_provide();

        vm.startPrank(user);
        uint256 actual = fdusdLpProvider.release(user, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(123e18, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(0, deposit);
    }

    function test_release_full_delegated() public {
        test_provide_delegate();

        vm.startPrank(user);
        uint256 actual = fdusdLpProvider.release(user, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(123e18, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(delegateTo));

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(0, deposit);
    }

    function test_release_full_recipient() public {
        test_provide();

        vm.startPrank(user);
        uint256 actual = fdusdLpProvider.release(recipient, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(2e18, FDUSD.balanceOf(user));
        assertEq(121e18, FDUSD.balanceOf(recipient));
        assertEq(0, clisFDUSD.balanceOf(user));

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(0, deposit);
    }

    function test_release_partial() public {
        test_provide();

        vm.startPrank(user);
        uint256 actual = fdusdLpProvider.release(user, 21e18);
        vm.stopPrank();

        assertEq(21e18, actual);
        assertEq(23e18, FDUSD.balanceOf(user));
        assertEq(100e18, clisFDUSD.balanceOf(user));

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(100e18, deposit);
    }

    function test_release_partial_delegated() public {
        test_provide_delegate();

        vm.startPrank(user);
        uint256 actual = fdusdLpProvider.release(user, 21e18);
        vm.stopPrank();

        assertEq(21e18, actual);
        assertEq(23e18, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(100e18, clisFDUSD.balanceOf(delegateTo));

        (address actualTo, uint256 amount) = fdusdLpProvider._delegation(user);
        assertEq(100e18, amount);
        assertEq(delegateTo, actualTo);

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(100e18, deposit);
    }

    function test_release_less_collateral() public {
        test_provide();
        deal(address(clisFDUSD), user, 10e18);

        vm.startPrank(user);
        uint256 actual = fdusdLpProvider.release(user, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(123e18, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(0, deposit);
    }

    function test_release_delegatee_mixed() public {
        // set up delegateTo's tokens
        deal(address(FDUSD), delegateTo, 123e18);

        vm.startPrank(delegateTo);
        FDUSD.approve(address(fdusdLpProvider), 121e18);
        fdusdLpProvider.provide(121e18);
        vm.stopPrank();

        assertEq(2e18, FDUSD.balanceOf(delegateTo));
        assertEq(121e18, clisFDUSD.balanceOf(delegateTo));

        (uint256 delegateToDeposit, ) = vat.urns(fdusdIlk, delegateTo);
        assertEq(121e18, delegateToDeposit);

        // clear delegateTo collateral tokens, make it like an old user
        deal(address(clisFDUSD), delegateTo, 0);
        assertEq(0, clisFDUSD.balanceOf(delegateTo));

        // set up user's tokens
        deal(address(FDUSD), user, 345e18);

        vm.startPrank(user);
        FDUSD.approve(address(fdusdLpProvider), 345e18);
        fdusdLpProvider.provide(345e18, delegateTo);
        vm.stopPrank();

        assertEq(0, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(345e18, clisFDUSD.balanceOf(delegateTo));

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(345e18, deposit);

        // user withdraw partially
        vm.startPrank(user);
        fdusdLpProvider.release(user, 11e18);
        vm.stopPrank();

        assertEq(11e18, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(334e18, clisFDUSD.balanceOf(delegateTo));

        (uint256 deposit0, ) = vat.urns(fdusdIlk, user);
        assertEq(334e18, deposit0);

        // delegateTo release should not burn delegatedAmount
        vm.startPrank(delegateTo);
        uint256 actual = fdusdLpProvider.release(delegateTo, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(123e18, FDUSD.balanceOf(delegateTo));
        assertEq(334e18, clisFDUSD.balanceOf(delegateTo));

        (uint256 afterDeposit, ) = vat.urns(fdusdIlk, delegateTo);
        assertEq(0, afterDeposit);
    }

    function test_daoBurn() public {
        test_provide();

        vm.startPrank(address(interaction));
        fdusdLpProvider.daoBurn(user, 121e18);
        vm.stopPrank();

        assertEq(0, clisFDUSD.balanceOf(user));
    }

    function test_daoBurn_delegated() public {
        test_provide_delegate();

        vm.startPrank(address(interaction));
        fdusdLpProvider.daoBurn(user, 121e18);
        vm.stopPrank();

        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(delegateTo));
    }
}
