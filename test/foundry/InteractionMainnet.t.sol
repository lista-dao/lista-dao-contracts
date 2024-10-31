// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { GemJoinLike } from "../../contracts/interfaces/GemJoinLike.sol";
import { Interaction } from "../../contracts/Interaction.sol";
import { Vat } from  "../../contracts/vat.sol";
import "../../contracts/interfaces/VatLike.sol";
import { Spotter } from  "../../contracts/spot.sol";
import { LisUSD } from "../../contracts/LisUSD.sol";
import { Jug } from "../../contracts/jug.sol";
import { Dog } from "../../contracts/dog.sol";
import { Clipper } from "../../contracts/clip.sol";
import { HayJoin, GemJoin } from "../../contracts/join.sol";


uint256 constant RAY = 10**27;

contract InteractionMainnetTest is Test {
    address user0 = address(0xFF00);
    address user1 = address(0xFF01);

    uint256 mainnet;

    bytes32 fdusdIlk;

    IERC20 FDUSD;

    VatLike vat;

    Interaction interaction;

    function setUp() public {
        mainnet = vm.createSelectFork("https://bsc-dataseed.binance.org");

        ProxyAdmin proxyAdmin = ProxyAdmin(address(0x1Fa3E4718168077975fF4039304CC2e19Ae58c4C));
        vm.startPrank(address(0x08aE09467ff962aF105c23775B9Bc8EAa175D27F));
        Interaction newInteraction = new Interaction();
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(address(0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4));
        proxyAdmin.upgrade(proxy, address(newInteraction));
        vm.stopPrank();

        FDUSD = IERC20(0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409);
        vat = VatLike(0x33A34eAB3ee892D40420507B820347b1cA2201c4);
        interaction = Interaction(0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4);

        (, bytes32 ilk, ,) = interaction.collaterals(address(FDUSD));
        fdusdIlk = ilk;
    }

    function test_setUp() public {
        assertEq(address(interaction), 0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4);
    }

    function test_deposit_fdusd() public {
        deal(address(FDUSD), user0, 1000 ether);

        vm.startPrank(user0);
        FDUSD.approve(address(interaction), 1000 ether);
        interaction.deposit(user0, address(FDUSD), 1000 ether);
        vm.stopPrank();

        (uint256 deposit, ) = vat.urns(fdusdIlk, user0);
        assertEq(1000 ether, deposit, "deposit should be 1000");
    }

    function test_borrow_fdusd() public {
        test_deposit_fdusd();

        vm.startPrank(user0);
        interaction.borrow(address(FDUSD), 100 ether);
        vm.stopPrank();

        assertEq(100 ether, interaction.hay().balanceOf(user0));
        assertEq(100 ether + 100, interaction.borrowed(address(FDUSD), user0));

        (, uint256 rate, , ,) = vat.ilks(fdusdIlk);
        (uint256 deposit1, uint256 borrow) = vat.urns(fdusdIlk, user0);
        assertEq(1000 ether, deposit1, "deposit1 should be 1000");
        assertEq(100 ether * RAY / rate + 1, borrow, "borrow check");
    }

    function test_payback_fdusd() public {
        test_borrow_fdusd();

        deal(address(interaction.hay()), user0, 101 ether);

        vm.startPrank(user0);
        interaction.hay().approve(address(interaction), 101 ether);
        interaction.payback(address(FDUSD), 101 ether);
        vm.stopPrank();

        (uint256 deposit1, uint256 borrow) = vat.urns(fdusdIlk, user0);
        assertEq(1000 ether, deposit1, "deposit1 check");
        assertEq(0, borrow, "borrow check");
    }

    function test_paybackAs_fdusd() public {
        test_borrow_fdusd();

        deal(address(interaction.hay()), user0, 0);
        deal(address(interaction.hay()), user1, 101 ether);

        vm.startPrank(user1);
        interaction.hay().approve(address(interaction), 101 ether);
        interaction.paybackAs(address(FDUSD), 101 ether, user0);
        vm.stopPrank();

        (uint256 deposit1, uint256 borrow) = vat.urns(fdusdIlk, user0);
        assertEq(1000 ether, deposit1, "deposit1 check");
        assertEq(0, borrow, "borrow check");
    }
}
