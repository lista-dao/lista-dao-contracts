// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { Interaction } from "../../contracts/Interaction.sol";
import { Vat } from  "../../contracts/vat.sol";
import { Spotter } from  "../../contracts/spot.sol";
import { LisUSD } from "../../contracts/LisUSD.sol";
import { Jug } from "../../contracts/jug.sol";
import { Dog } from "../../contracts/dog.sol";
import { Clipper } from "../../contracts/clip.sol";
import { HayJoin, GemJoin } from "../../contracts/join.sol";


contract InteractionTest is Test {
    address public proxyAdminOwner = address(0x2A11AA);

    Interaction interaction;
    Vat vat;
    Spotter spotter;
    LisUSD hay;
    HayJoin hayJoin;
    Jug jug;
    Dog dog;

    address public collateral = address(0xAA);  // random address
    bytes32 public ilk = "collateral-A";  // random ilk
    uint256 public mat = 1515151515151515151515151515;  // 151% MCR


    address public user = address(0x123);  // random user

    function setUp() public {
        vat = new Vat();
        spotter = new Spotter();
        hay = new LisUSD();
        hayJoin = new HayJoin();
        jug = new Jug();
        dog = new Dog();

        Interaction interactionImpl = new Interaction();

        TransparentUpgradeableProxy interactionProxy = new TransparentUpgradeableProxy(
            address(interactionImpl),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address,address)",
                address(vat), address(spotter), address(hay), address(hayJoin), address(jug), address(dog), address(0) // last one is rewards
            )
        );
        interaction = Interaction(address(interactionProxy));
    }

    function testRevert_initialize() public {
        vm.expectRevert("Initializable: contract is already initialized");
        interaction.initialize(address(vat), address(spotter), address(hay), address(hayJoin), address(jug), address(dog), address(0));

        assertEq(address(vat), address(interaction.vat()));
        assertEq(address(spotter), address(interaction.spotter()));
        assertEq(address(hay), address(interaction.hay()));
        assertEq(address(hayJoin), address(interaction.hayJoin()));
        assertEq(address(jug), address(interaction.jug()));
        assertEq(address(dog), interaction.dog());
        assertEq(address(0), address(interaction.helioRewards()));

        assertEq(type(uint256).max, hay.allowance(address(interaction), address(hayJoin)));
        assertEq(1, vat.can(address(interaction), address(hayJoin)));

        assertEq(1, interaction.wards(address(this)));
    }

    function test_setCollateralType() public {
        GemJoin gemJoin = new GemJoin();
        Clipper clipper = new Clipper();

        vm.mockCall(address(vat), abi.encodeWithSelector(Vat.init.selector), abi.encode(0x00));
        vm.mockCall(address(vat), abi.encodeWithSelector(Vat.rely.selector), abi.encode(0x00));
        vm.mockCall(address(jug), abi.encodeWithSelector(Jug.init.selector), abi.encode(0x00));
        vm.mockCall(
            address(spotter),
            abi.encodeWithSignature("file(bytes32,bytes32,uint256)", ilk, bytes32("mat"), mat),
            abi.encode(0x00)
        );
        vm.mockCall(
            collateral,
            abi.encodeWithSignature("safeApprove(address,uint256)", address(gemJoin), type(uint256).max),
            abi.encode(0x00)
        );



        //interaction.setCollateralType(collateral, address(gemJoin), ilk, address(clipper), mat);
    }

    function testRevert_setCollateralType() public {
        GemJoin gemJoin = new GemJoin();
        Clipper clipper = new Clipper();

        vm.startPrank(user);
        vm.expectRevert("Interaction/not-authorized");
        interaction.setCollateralType(collateral, address(gemJoin), ilk, address(clipper), mat);
        vm.stopPrank();

        vm.expectRevert("Vat/not-authorized");
        interaction.setCollateralType(collateral, address(gemJoin), ilk, address(clipper), mat);
    }
}