pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../contracts/LisUSD.sol";
import "../../contracts/old/LisUSDOld.sol";


contract LisUSDAclTest is Test {
    address user0 = address(0x0A11AA);
    address user1 = address(0x1A11AA);

    address newAdmin0 = address(0x2A11AA);
    address newAdmin1 = address(0x3A11AA);

    address manager0 = address(0x4A11AA);
    address manager1 = address(0x5A11AA);

    address sender;

    uint256 mainnet;

    LisUSDOld oldLisUSD;

    LisUSD lisUSD;

    function setUp() public {
        mainnet = vm.createSelectFork("https://bsc-dataseed.binance.org");
        oldLisUSD = LisUSDOld(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);

        // HayJoin
        vm.startPrank(0x4C798F81de7736620Cd8e6510158b1fE758e22F7);
        oldLisUSD.mint(user0, 100 ether);
        vm.stopPrank();

        assertEq(100 ether, oldLisUSD.balanceOf(user0));

        ProxyAdmin proxyAdmin = ProxyAdmin(address(0x1Fa3E4718168077975fF4039304CC2e19Ae58c4C));
        vm.startPrank(address(proxyAdmin.owner()));
        LisUSD newLisUSD = new LisUSD();
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(address(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5));
        proxyAdmin.upgrade(proxy, address(newLisUSD));
        vm.stopPrank();

        lisUSD = LisUSD(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);
    }

    function test_setUp() public {
        deal(address(lisUSD), user0, 0);

        // HayJoin
        vm.startPrank(0x4C798F81de7736620Cd8e6510158b1fE758e22F7);
        lisUSD.mint(user0, 100 ether);
        vm.stopPrank();

        assertEq(100 ether, lisUSD.balanceOf(user0));
    }

    function test_rely_minter() public {
        vm.startPrank(lisUSD.DEFAULT_ADMIN());
        lisUSD.rely(newAdmin0, 1);
        vm.stopPrank();

        assertEq(1, lisUSD.wards(newAdmin0));

        vm.startPrank(newAdmin0);
        lisUSD.mint(user1, 100 ether);
        vm.stopPrank();
        assertEq(100 ether, lisUSD.balanceOf(user1));

        // HayJoin
        vm.startPrank(0x4C798F81de7736620Cd8e6510158b1fE758e22F7);
        vm.expectRevert("LisUSD/not-authorized-admin");
        lisUSD.rely(newAdmin1, 1);
        vm.stopPrank();
    }

    function test_deny_minter() public {
        test_rely_minter();

        vm.startPrank(0x4C798F81de7736620Cd8e6510158b1fE758e22F7);
        vm.expectRevert("LisUSD/not-authorized-admin");
        lisUSD.deny(newAdmin0);
        vm.stopPrank();
        assertEq(1, lisUSD.wards(newAdmin0));

        vm.startPrank(lisUSD.DEFAULT_ADMIN());
        lisUSD.deny(newAdmin0);
        vm.stopPrank();
        assertEq(0, lisUSD.wards(newAdmin0));

        // unable to mint
        vm.startPrank(newAdmin0);
        vm.expectRevert("LisUSD/not-authorized-minter");
        lisUSD.mint(user0, 100 ether);
        vm.stopPrank();
    }

    function test_rely_manager() public {
        vm.startPrank(manager0);
        vm.expectRevert("LisUSD/not-authorized-manager");
        lisUSD.setSupplyCap(80_000_000 ether);
        vm.stopPrank();

        vm.startPrank(lisUSD.DEFAULT_ADMIN());
        lisUSD.rely(manager0, 2);
        vm.stopPrank();

        vm.startPrank(manager0);
        lisUSD.setSupplyCap(80_000_000 ether);
        vm.stopPrank();
        assertEq(80_000_000 ether, lisUSD.supplyCap());

        // unable to mint
        vm.startPrank(manager0);
        vm.expectRevert("LisUSD/not-authorized-minter");
        lisUSD.mint(user0, 100 ether);
        vm.stopPrank();
    }

    function test_rely_admin() public {
        vm.startPrank(newAdmin1);
        vm.expectRevert("LisUSD/not-authorized-admin");
        lisUSD.rely(address(1), 3);
        vm.stopPrank();

        vm.startPrank(lisUSD.DEFAULT_ADMIN());
        lisUSD.rely(newAdmin1, 3);
        vm.stopPrank();
        assertEq(3, lisUSD.wards(newAdmin1));

        // unable to mint
        vm.startPrank(newAdmin1);
        vm.expectRevert("LisUSD/not-authorized-minter");
        lisUSD.mint(user0, 100 ether);
        vm.stopPrank();

        vm.startPrank(newAdmin1);
        lisUSD.rely(address(1), 3);
        vm.stopPrank();
        assertEq(3, lisUSD.wards(address(1)));

        vm.startPrank(address(1));
        lisUSD.rely(address(2), 3);
        vm.stopPrank();
        assertEq(3, lisUSD.wards(address(2)));
    }
}
