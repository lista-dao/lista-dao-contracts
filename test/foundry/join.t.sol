// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { GemJoin5 } from "../../contracts/join-5.sol";
import { Vat } from "../../contracts/vat.sol";

contract GemJoinTest is Test {
  GemJoin5 gemJoin;
  Vat vat;
  ERC20 gem;

  address user1 = makeAddr("user1");
  bytes32 ilk = bytes32("Foo");

  function setUp() public {
    vat = new Vat();
    gemJoin = new GemJoin5();
    gem = new ERC20("foo", "Foo");
    deal(address(gem), user1, 1000 ether);

    vat.initialize();
    vat.rely(address(gemJoin));

    vm.mockCall(address(gem), abi.encodeWithSelector(ERC20.decimals.selector), abi.encode(0x08));
    gemJoin.initialize(address(vat), ilk, address(gem));

    assertEq(gemJoin.dec(), 8);
    assertEq(gemJoin.live(), 1);
    assertEq(address(gemJoin.gem()), address(gem));
  }

  function test_join() public {
    vm.startPrank(user1);

    uint256 amt = 1000;
    gem.approve(address(gemJoin), amt);
    gemJoin.join(user1, amt);

    uint256 scale = 18 - gemJoin.dec();
    assertEq(vat.gem(ilk, user1), amt * 10 ** scale);
    assertEq(gem.balanceOf(address(gemJoin)), amt);
  }

  function test_exit() public {
    vm.startPrank(user1);

    // Join
    uint256 amt = 1000;
    gem.approve(address(gemJoin), amt);
    gemJoin.join(user1, amt);

    uint256 scale = 18 - gemJoin.dec();
    assertEq(vat.gem(ilk, user1), amt * 10 ** scale);
    assertEq(gem.balanceOf(address(gemJoin)), amt);

    // Exit
    gemJoin.exit(user1, amt);
    assertEq(vat.gem(ilk, user1), 0);
    assertEq(gem.balanceOf(address(gemJoin)), 0);
    assertEq(gem.balanceOf(user1), 1000 ether);
  }

  function test_cage() public {
    vm.prank(user1);
    vm.expectRevert();
    gemJoin.cage();

    gemJoin.cage();
    assertEq(gemJoin.live(), 0);
    gemJoin.uncage();
    assertEq(gemJoin.live(), 1);
  }
}
