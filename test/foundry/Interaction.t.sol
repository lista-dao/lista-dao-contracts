// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { GemJoinLike } from "../../contracts/interfaces/GemJoinLike.sol";
import { Interaction } from "../../contracts/Interaction.sol";
import { Vat } from "../../contracts/vat.sol";
import { Spotter } from "../../contracts/spot.sol";
import { LisUSD } from "../../contracts/LisUSD.sol";
import { Jug } from "../../contracts/jug.sol";
import { Dog } from "../../contracts/dog.sol";
import { Clipper } from "../../contracts/clip.sol";
import { HayJoin, GemJoin } from "../../contracts/join.sol";
import { DynamicDutyCalculator } from "../../contracts/amo/DynamicDutyCalculator.sol";

contract InteractionTest is Test {
  address public proxyAdminOwner = address(0x2A11AA);

  Interaction interaction;
  Vat vat;
  Spotter spotter;
  LisUSD hay;
  HayJoin hayJoin;
  Jug jug;
  Dog dog;

  address public collateral = address(0xAA); // random address
  bytes32 public ilk = "collateral-A"; // random ilk
  uint256 public mat = 1515151515151515151515151515; // 151% MCR

  address public user = address(0x123); // random user

  function setUp() public {
    vat = new Vat();
    spotter = new Spotter();
    hay = new LisUSD();
    hayJoin = new HayJoin();
    dog = new Dog();
    jug = new Jug();

    Interaction interactionImpl = new Interaction();

    TransparentUpgradeableProxy interactionProxy = new TransparentUpgradeableProxy(
      address(interactionImpl),
      proxyAdminOwner,
      abi.encodeWithSignature(
        "initialize(address,address,address,address,address,address)",
        address(vat),
        address(spotter),
        address(hay),
        address(hayJoin),
        address(jug),
        address(dog)
      )
    );
    interaction = Interaction(address(interactionProxy));
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

  function testRevert_initialize() public {
    vm.expectRevert("Initializable: contract is already initialized");
    interaction.initialize(address(vat), address(spotter), address(hay), address(hayJoin), address(jug), address(dog));
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
      abi.encodeWithSignature("allowance(address,address)", address(interaction), address(gemJoin)),
      abi.encode(0x00)
    );
    vm.mockCall(
      collateral,
      abi.encodeWithSignature("approve(address,uint256)", address(gemJoin), type(uint256).max),
      abi.encode(0x01)
    );

    interaction.setCollateralType(collateral, address(gemJoin), ilk, address(clipper), mat);

    (GemJoinLike _gem, bytes32 _ilk, uint32 _live, address _clip) = interaction.collaterals(collateral);

    assertEq(address(gemJoin), address(_gem));
    assertEq(ilk, _ilk);
    assertEq(1, _live);
    assertEq(address(clipper), _clip);
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

  function test_setDutyCalculator() public {
    DynamicDutyCalculator dutyCalculator = new DynamicDutyCalculator();

    vm.mockCall(address(dutyCalculator), abi.encodeWithSignature("interaction()"), abi.encode(address(interaction)));

    interaction.setDutyCalculator(address(dutyCalculator));
    assertEq(address(dutyCalculator), address(interaction.dutyCalculator()));
  }

  function testRevert_setDutyCalculator() public {
    DynamicDutyCalculator dutyCalculator = new DynamicDutyCalculator();

    vm.expectRevert("invalid-dutyCalculator-var");
    interaction.setDutyCalculator(address(dutyCalculator));
  }

  function test_setCollateralDuty() public {
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
      abi.encodeWithSignature("allowance(address,address)", address(interaction), address(gemJoin)),
      abi.encode(0x00)
    );
    vm.mockCall(
      collateral,
      abi.encodeWithSignature("approve(address,uint256)", address(gemJoin), type(uint256).max),
      abi.encode(0x01)
    );

    interaction.setCollateralType(collateral, address(gemJoin), ilk, address(clipper), mat);

    (GemJoinLike _gem, bytes32 _ilk, uint32 _live, address _clip) = interaction.collaterals(collateral);

    assertEq(address(gemJoin), address(_gem));
    assertEq(ilk, _ilk);
    assertEq(1, _live);
    assertEq(address(clipper), _clip);

    uint256 newDuty = 1000000004466999177996065553; // 15.1% APY

    vm.mockCall(address(jug), abi.encodeWithSignature("drip(bytes32)", ilk), abi.encode(0x00));
    vm.mockCall(address(jug), abi.encodeWithSignature("wards(address)", address(interaction)), abi.encode(0x01));
    vm.mockCall(
      address(jug),
      abi.encodeWithSignature("file(bytes32,bytes32,uint256)", ilk, bytes32("duty"), newDuty),
      abi.encode(0x00)
    );

    interaction.setCollateralDuty(collateral, newDuty);
  }

  function test_drip() public {
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
      abi.encodeWithSignature("allowance(address,address)", address(interaction), address(gemJoin)),
      abi.encode(0x00)
    );
    vm.mockCall(
      collateral,
      abi.encodeWithSignature("approve(address,uint256)", address(gemJoin), type(uint256).max),
      abi.encode(0x01)
    );

    interaction.setCollateralType(collateral, address(gemJoin), ilk, address(clipper), mat);

    DynamicDutyCalculator dutyCalculator = new DynamicDutyCalculator();

    vm.mockCall(address(dutyCalculator), abi.encodeWithSignature("interaction()"), abi.encode(address(interaction)));

    interaction.setDutyCalculator(address(dutyCalculator));

    uint256 newDuty = 1000000004466999177996065553; // 15.1% APY

    vm.mockCall(
      address(dutyCalculator),
      abi.encodeWithSelector(DynamicDutyCalculator.calculateDuty.selector),
      abi.encode(newDuty)
    );

    vm.mockCall(address(jug), abi.encodeWithSignature("drip(bytes32)", ilk), abi.encode(0x00));
    vm.mockCall(address(jug), abi.encodeWithSignature("wards(address)", address(interaction)), abi.encode(0x01));
    vm.mockCall(
      address(jug),
      abi.encodeWithSignature("file(bytes32,bytes32,uint256)", ilk, bytes32("duty"), newDuty),
      abi.encode(0x00)
    );

    vm.startPrank(user);
    interaction.drip(collateral);
    vm.stopPrank();
  }

  function test_getNextDuty() public {
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
      abi.encodeWithSignature("allowance(address,address)", address(interaction), address(gemJoin)),
      abi.encode(0x00)
    );
    vm.mockCall(
      collateral,
      abi.encodeWithSignature("approve(address,uint256)", address(gemJoin), type(uint256).max),
      abi.encode(0x01)
    );

    interaction.setCollateralType(collateral, address(gemJoin), ilk, address(clipper), mat);

    DynamicDutyCalculator dutyCalculator = new DynamicDutyCalculator();

    vm.mockCall(address(dutyCalculator), abi.encodeWithSignature("interaction()"), abi.encode(address(interaction)));

    interaction.setDutyCalculator(address(dutyCalculator));
    uint256 newDuty = 1000000004466999177996065553; // 15.1% APY

    vm.mockCall(
      address(dutyCalculator),
      abi.encodeWithSelector(DynamicDutyCalculator.calculateDuty.selector),
      abi.encode(newDuty)
    );

    vm.record();
    vm.recordLogs();
    uint256 _duty = interaction.getNextDuty(collateral);
    assertEq(newDuty, _duty);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 0);
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(interaction));
    assertEq(writes.length, 0);
  }
}
