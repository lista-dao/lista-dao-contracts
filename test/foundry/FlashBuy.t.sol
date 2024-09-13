// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../contracts/FlashBuy.sol";
import "../../contracts/LisUSD.sol";


contract FlashBuyTest is Test {
    address proxyAdminOwner = address(0x2A11AA);

    address admin;

    address lisUSD;

    FlashBuy flashBuy;

    function setUp() public {
        admin = msg.sender;
        lisUSD = address(new LisUSD());

        FlashBuy flashBuyImpl = new FlashBuy();
        TransparentUpgradeableProxy flashBuyProxy = new TransparentUpgradeableProxy(
            address(flashBuyImpl),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(address,address,address)",
                address(0xffff), address(0xeeee), address(0xdddd)
            )
        );

        flashBuy = FlashBuy(address(flashBuyProxy));
        flashBuy.transferOwnership(admin);
    }

    function test_setup() public {
        assertTrue(address(flashBuy) != address(0));
        assertEq(address(0xffff), address(flashBuy.lender()));
    }

    function test_changeRevenuePool_ok() public {
        assertEq(address(0), flashBuy.revenuePool());

        vm.startPrank(admin);
        flashBuy.changeRevenuePool(address(0x1234));
        vm.stopPrank();

        assertEq(address(0x1234), flashBuy.revenuePool());
    }

    function test_changeRevenuePool_acl() public {
        assertEq(address(0), flashBuy.revenuePool());

        vm.startPrank(address(0xffff));
        vm.expectRevert("Ownable: caller is not the owner");
        flashBuy.changeRevenuePool(address(0x1234));
        vm.stopPrank();

        assertEq(address(0), flashBuy.revenuePool());
    }

    function test_transfer_invalid_pool() public {
        deal(lisUSD, address(flashBuy), 123e18);

        assertEq(123e18, IERC20(lisUSD).balanceOf(address(flashBuy)));

        vm.expectRevert("Revenue pool not set");
        flashBuy.transfer(lisUSD);

        assertEq(123e18, IERC20(lisUSD).balanceOf(address(flashBuy)));
    }

    function test_transfer_ok() public {
        test_changeRevenuePool_ok();

        deal(lisUSD, address(flashBuy), 123e18);
        assertEq(123e18, IERC20(lisUSD).balanceOf(address(flashBuy)));

        flashBuy.transfer(lisUSD);

        assertEq(0, IERC20(lisUSD).balanceOf(address(flashBuy)));
        assertEq(123e18, IERC20(lisUSD).balanceOf(address(0x1234)));
    }
}
