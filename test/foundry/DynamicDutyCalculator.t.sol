// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../contracts/amo/DynamicDutyCalculator.sol";
import "../../contracts/Interaction.sol";
import "../../contracts/LisUSD.sol";
import "../../contracts/oracle/ResilientOracle.sol";

contract DynamicDutyCalculatorTest is Test {
    DynamicDutyCalculator dynamicDutyCalculator;
    Interaction interaction;
    ResilientOracle oracle;

    address lisUSD;
    uint256 delta = 200000;

    address public proxyAdminOwner = address(0x2A11AA);
    address public bot = address(0x3A11AA);

    address public collateral = address(0x5A11AA);  // random address
    address public collateral1 = address(0x6A11AA);  // random address

    uint256 beta = 1e6;
    uint256 rate0 = 3309234382829741600; // 11% APY
    uint256 rate0_15p = 4431822000000000000; // 15% APY
    uint256 rate0_400p = 51034942716352291304; // 400% APY

    address admin;

    function setUp() public {
        DynamicDutyCalculator dynamicDutyCalculatorImpl = new DynamicDutyCalculator();
        interaction = new Interaction();
        oracle = new ResilientOracle();
        lisUSD = address(new LisUSD());

        admin = msg.sender;

        vm.expectRevert("AMO/invalid-delta");
        TransparentUpgradeableProxy __dynamicDutyCalculatorProxy = new TransparentUpgradeableProxy(
            address(dynamicDutyCalculatorImpl),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,address)",
                address(interaction), address(lisUSD), address(oracle), 20000000, msg.sender
            )
        );

        TransparentUpgradeableProxy dynamicDutyCalculatorProxy = new TransparentUpgradeableProxy(
            address(dynamicDutyCalculatorImpl),
            proxyAdminOwner,
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,address)",
                address(interaction), address(lisUSD), address(oracle), delta, msg.sender
            )
        );
        dynamicDutyCalculator = DynamicDutyCalculator(address(dynamicDutyCalculatorProxy));

        vm.startPrank(msg.sender);
        dynamicDutyCalculator.grantRole(dynamicDutyCalculator.BOT(), bot);
        vm.stopPrank();
    }

    function testRevert_initialize() public {
        vm.expectRevert("Initializable: contract is already initialized");
        dynamicDutyCalculator.initialize(address(interaction), address(lisUSD), address(oracle), delta, msg.sender);

        assertEq(dynamicDutyCalculator.interaction(), address(interaction));
        assertEq(dynamicDutyCalculator.minDuty(), 1e27);
        assertEq(dynamicDutyCalculator.maxDuty(), 1000000034836767751273470154);
        assertEq(dynamicDutyCalculator.minPrice(), 9e7);
        assertEq(dynamicDutyCalculator.maxPrice(), 11e7);
        assertEq(dynamicDutyCalculator.delta(), delta);

        assertEq(dynamicDutyCalculator.hasRole(dynamicDutyCalculator.DEFAULT_ADMIN_ROLE(), msg.sender), true);
        assertEq(dynamicDutyCalculator.hasRole(dynamicDutyCalculator.INTERACTION(), address(interaction)), true);
        assertEq(dynamicDutyCalculator.getRoleAdmin(dynamicDutyCalculator.INTERACTION()), dynamicDutyCalculator.DEFAULT_ADMIN_ROLE());

        vm.expectRevert("Initializable: contract is already initialized");
        dynamicDutyCalculator.initialize(address(interaction), address(lisUSD), address(oracle), 20000000, msg.sender);

   }

   function test_setCollateralParams() public {
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99000000)) // returns $0.99
        );

        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );

        vm.startPrank(admin);
        bool enabled = true;
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, enabled);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice, uint256 _rate0, uint256 _beta) = dynamicDutyCalculator.ilks(collateral);

        assertEq(_beta, beta);
        assertEq(_rate0, rate0);
        assertEq(_enabled, enabled);
        assertEq(_lastPrice, 99000000);
   }

   function testRevert_setCollateralParams() public {
        vm.expectRevert();
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);

        vm.startPrank(admin);
        vm.expectRevert("AMO/invalid-beta");
        dynamicDutyCalculator.setCollateralParams(collateral, 3e5, rate0, true);
        vm.stopPrank();

        vm.startPrank(admin);
        vm.expectRevert("AMO/invalid-beta");
        dynamicDutyCalculator.setCollateralParams(collateral, 1e8, rate0, true);
        vm.stopPrank();
   }

   function test_calculateDuty_0_950() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99000000)) // returns $0.99
        );
        assertEq(oracle.peek(lisUSD), 99000000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(95000000)) // returns $0.95
        );
        assertEq(oracle.peek(lisUSD), 95000000);


        vm.startPrank(address(interaction));
        uint256 currentDuty = 1000000003309234382829741600;
        bool updateLastPrice = true;
        uint256 duty = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // 491133928966627332924 = 3309234382829741600 * factor
        // factor = e^(delta/sigma) = e^(5000000/1e6) = e^5 = 148.413159102576603421115580040552
        // 1000000491133928966627332924 > maxDuty
        assertEq(duty, dynamicDutyCalculator.maxDuty());
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());
        (,uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 95000000);
   }

   function test_calculateDuty_0_997_ilk_disabled() public {
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99700000)) // returns $0.997
        );
        assertEq(oracle.peek(lisUSD), 99700000);

        assertEq(dynamicDutyCalculator.delta(), 200000);
        (bool _enabled, uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 0);
        assertEq(_enabled, false);

        vm.startPrank(address(interaction));
        uint256 currentDuty = 1000000002877801985002874874; // 9.5%
        bool updateLastPrice = true;
        uint256 duty = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // duty should be the same as the collateral is disabled
        assertEq(duty, currentDuty);
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());
        (,_lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 0);
   }

   function test_calculateDuty_0_997_normal() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99700000)) // returns $0.997
        );

        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();
        assertEq(oracle.peek(lisUSD), 99700000);

        (bool _enabled, uint256 _lastPrice, uint _rate0, uint _beta) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99700000);
        assertEq(_enabled, true);

        vm.startPrank(address(interaction));

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99910000)) // returns $0.9991
        );
        assertEq(oracle.peek(lisUSD), 99910000);

        uint256 currentDuty = 1000000004466999177996065553;
        bool updateLastPrice = true;
        uint256 duty = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // 3620879160445386386 = 3309234382829741600 * factor
        // factor = e^(delta/beta) = e^(90000/1e6) = e^0.09 = 1.09417428371
        // 3309234382829741600 * 1.09417428371 = 3620879160445386386
        assertEq(duty, 1000000003620879160445386386);
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());
        (,_lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99910000);
   }

   function test_calculateDuty_1_011_normal() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(101100000)) // returns $1.011
        );
        assertEq(oracle.peek(lisUSD), 101100000);

        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice, uint _rate0, uint _beta) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 101100000);
        assertEq(_enabled, true);

        vm.startPrank(address(interaction));
        uint256 currentDuty = 1000000001101548435223481549; // 3.5% APY
        bool updateLastPrice = true;

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(103100000)) // returns $1.031
        );
        uint256 duty = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // 149078369479817384 = 3309234382829741600 * factor
        // factor = e^(delta/beta) = e^(-3100000/1e6) = e^(-3.1) = 0.04504920239
        // 3309234382829741600 * 0.04504920239 = 149078369479817384
        assertEq(duty, 1000000000149078369479817384);
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());

        (,_lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 103100000);
   }

   function test_calculateDuty_1_011_disabled() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(101100000)) // returns $1.011
        );
        assertEq(oracle.peek(lisUSD), 101100000);
        (bool _enabled, uint256 _lastPrice, uint _rate0, uint _beta) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 0);
        assertEq(_enabled, false);

        uint256 currentDuty = 1000000004466999177996065553; // 15.1% APY
        bool updateLastPrice = true;
        vm.startPrank(address(interaction));
        uint256 duty = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();
        assertEq(duty, currentDuty); // return current duty as the collateral is disabled
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());

        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, false);
        vm.stopPrank();

        (_enabled, _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 101100000);
        assertEq(_enabled, false);

        vm.startPrank(address(interaction));
        duty = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        assertEq(duty, currentDuty); // return current duty as the collateral is disabled
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());
        (,_lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 101100000);
   }

    function test_calculateDuty_0_999_to_0_899_return_maxDuty() public {
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99900000)) // returns $0.999
        );
        assertEq(oracle.peek(lisUSD), 99900000);

        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );

        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
        assertEq(_enabled, true);

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(89900000)) // returns $0.899
        );
        assertEq(oracle.peek(lisUSD), 89900000);

        uint256 duty = 1000000004466999177996065553; // 15.1% APY
        vm.startPrank(address(interaction));
        duty = dynamicDutyCalculator.calculateDuty(collateral, duty, true);
        vm.stopPrank();

        // price: 0.999 -> 0.899
        // duty -> maxDuty
        assertEq(duty, dynamicDutyCalculator.maxDuty());
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());
        (,_lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 89900000);
    }

    function test_calculateDuty_0_999_to_1_101_return_minDuty() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99900000)) // returns $0.999
        );

        assertEq(oracle.peek(lisUSD), 99900000);
        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
        assertEq(_enabled, true);

        uint256 currentDuty = 1000000004466999177996065553; // 15.1% APY
        bool updateLastPrice = true;

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(110100000)) // returns $1.101
        );
        assertEq(oracle.peek(lisUSD), 110100000);

        vm.startPrank(address(interaction));
        uint256 duty = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // price: 0.999 -> 1.101
        // duty -> minDuty
        assertEq(duty, dynamicDutyCalculator.minDuty());
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());
        (,_lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 110100000);
    }

    function test_calculateDuty_0_999_to_0_997() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99900000)) // returns $0.999
        );
        assertEq(oracle.peek(lisUSD), 99900000);
        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
        assertEq(_enabled, true);

        uint256 currentDuty = 1000000004466999177996065553; // 15.1% APY
        bool updateLastPrice = true;

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99700000)) // returns $0.999
        );
        assertEq(oracle.peek(lisUSD), 99700000);

        vm.startPrank(address(interaction));
        uint256 dutyAfter = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // price: 0.999 -> 0.997
        // lastPrice: 0.999 -> 0.999
        // APY: 12.2% -> 12.2%
        assertEq(dutyAfter, currentDuty); // duty should be the same as the change in price is within the delta
        assertLe(dutyAfter, dynamicDutyCalculator.maxDuty());
        assertGe(dutyAfter, dynamicDutyCalculator.minDuty());
        (, _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
    }

    function test_calculateDuty_0_999_to_1_001() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99900000)) // returns $0.999
        );
        assertEq(oracle.peek(lisUSD), 99900000);

        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
        assertEq(_enabled, true);

        uint256 currentDuty = 1000000004466999177996065553; // 15.1% APY
        bool updateLastPrice = true;

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(100100000)) // returns $1.001
        );
        assertEq(oracle.peek(lisUSD), 100100000);

        vm.startPrank(address(interaction));
        uint256 dutyAfter = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // price: 0.999 -> 1.001
        // lastPrice: 0.999 -> 0.999
        // APY: 12.2% -> 12.2%
        assertEq(dutyAfter, currentDuty); // duty should be the same as the price change is within the delta
        assertLe(dutyAfter, dynamicDutyCalculator.maxDuty());
        assertGe(dutyAfter, dynamicDutyCalculator.minDuty());
        (, _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
    }


    function test_calculateDuty_0_999_to_1_002() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99900000)) // returns $0.999
        );
        assertEq(oracle.peek(lisUSD), 99900000);

        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
        assertEq(_enabled, true);

        uint256 currentDuty = 1000000004466999177996065553; // 15.1% APY
        bool updateLastPrice = true;
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(100200000)) // returns $1.002
        );
        assertEq(oracle.peek(lisUSD), 100200000);

        vm.startPrank(address(interaction));
        uint256 dutyAfter = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // price: 0.999 -> 1.002
        // lastPrice: 0.999 -> 1.002
        // APY: 12.2% -> 8.9%
        assertEq(dutyAfter, 1000000002709371958365744856);
        assertLe(dutyAfter, dynamicDutyCalculator.maxDuty());
        assertGe(dutyAfter, dynamicDutyCalculator.minDuty());
        (, _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 100200000);
    }

    function test_calculateDuty_1_099_to_0_901_return_maxDuty() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(109900000)) // returns $1.099
        );
        assertEq(dynamicDutyCalculator.delta(), 200000);

        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();
        assertEq(oracle.peek(lisUSD), 109900000);

        (bool _enabled, uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 109900000);
        assertEq(_enabled, true);

        uint256 currentDuty = 1000000004466999177996065553; // 15.1% APY
        bool updateLastPrice = true;

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(90100000)) // returns $0.901
        );
        assertEq(oracle.peek(lisUSD), 90100000);

        vm.startPrank(address(interaction));
        uint256 dutyAfter = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
        vm.stopPrank();

        // price: 1.099 -> 0.901
        // lastPrice: 1.099 -> 0.901
        // APY: 0.000_005 % -> 200 %
        assertEq(dutyAfter, dynamicDutyCalculator.maxDuty());
        assertLe(dutyAfter, dynamicDutyCalculator.maxDuty());
        assertGe(dutyAfter, dynamicDutyCalculator.minDuty());
        (, _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 90100000);
    }

    function test_calculateDuty_no_update_lastPrice() public {
        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99900000)) // returns $0.999
        );
        assertEq(oracle.peek(lisUSD), 99900000);

        assertEq(dynamicDutyCalculator.delta(), 200000);
        vm.startPrank(admin);
        dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, true);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
        assertEq(_enabled, true);

        vm.startPrank(address(interaction));
        uint256 currentDuty = 1000000004466999177996065553; // 15.1% APY
        bool updateLastPrice = false;

	    vm.record();
	    vm.recordLogs();
        uint256 duty = dynamicDutyCalculator.calculateDuty(collateral, currentDuty, updateLastPrice);
	    Vm.Log[] memory entries = vm.getRecordedLogs();
	    assertEq(entries.length, 0);
	    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(dynamicDutyCalculator));
	    assertEq(writes.length, 0);

        vm.stopPrank();

        // lastPrice: 0 -> 0.999
        // APY: 15.1% -> 12.2%
        assertEq(duty, currentDuty);
        assertLe(duty, dynamicDutyCalculator.maxDuty());
        assertGe(duty, dynamicDutyCalculator.minDuty());
        (, _lastPrice,,) = dynamicDutyCalculator.ilks(collateral);
        assertEq(_lastPrice, 99900000);
    }

   function test_setPriceRange() public {
        vm.startPrank(admin);
        uint256 _minPrice = 8e7; // $0.80
        uint256 _maxPrice = 12e7; // $1.20
        dynamicDutyCalculator.setPriceRange(_minPrice, _maxPrice);
        vm.stopPrank();

        assertEq(dynamicDutyCalculator.minPrice(), _minPrice);
        assertEq(dynamicDutyCalculator.maxPrice(), _maxPrice);
   }

   function testRevert_setPriceRange() public {
        vm.expectRevert();
        dynamicDutyCalculator.setPriceRange(7e7, 12e7);
   }

   function test_setDutyRange() public {
        vm.startPrank(admin);
        uint256 _minDuty = 1e27;
        uint256 _maxDuty = 1000000051034942716352291304; // 400% APY
        dynamicDutyCalculator.setDutyRange(_minDuty, _maxDuty);
        vm.stopPrank();

        assertEq(dynamicDutyCalculator.minDuty(), _minDuty);
        assertEq(dynamicDutyCalculator.maxDuty(), _maxDuty);
   }

   function test_setDelta() public {
        vm.startPrank(admin);
        uint256 _delta = 100000;
        dynamicDutyCalculator.setDelta(_delta);
        vm.stopPrank();

        assertEq(dynamicDutyCalculator.delta(), _delta);
   }

   function testRevert_setDelta() public {
        vm.startPrank(admin);
        uint256 _delta = 20000000;
        vm.expectRevert("AMO/delta-is-too-large");
        dynamicDutyCalculator.setDelta(_delta);
        vm.stopPrank();
   }

   function test_file() public {
        vm.startPrank(admin);
        dynamicDutyCalculator.file("interaction", address(0xAA));
        dynamicDutyCalculator.file("lisUSD", address(0xBB));
        dynamicDutyCalculator.file("oracle", address(0xCC));
        vm.stopPrank();

        (address _interaction, address _lisUSD, address _oracle) = dynamicDutyCalculator.getContracts();
        assertEq(_interaction, address(0xAA));
        assertEq(dynamicDutyCalculator.hasRole(dynamicDutyCalculator.INTERACTION(), address(interaction)), false);
        assertEq(dynamicDutyCalculator.hasRole(dynamicDutyCalculator.INTERACTION(), _interaction), true);
        assertEq(_lisUSD, address(0xBB));
        assertEq(_oracle, address(0xCC));
   }

   function testRevert_file() public {
        vm.expectRevert();
        dynamicDutyCalculator.file("interaction", address(0xAA));

        vm.startPrank(admin);
        vm.expectRevert("AMO/file-unrecognized-param");
        dynamicDutyCalculator.file("proxy", address(0xAA));
        vm.stopPrank();
   }

    function test_setCollateralRate0() public {
        test_setCollateralParams();

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(99500000)) // returns $0.995
        );

        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );

        vm.startPrank(bot);
        address[] memory collaterals = new address[](1);
        collaterals[0] = collateral;
        uint256[] memory rates = new uint256[](1);
        rates[0] = rate0_15p;
        dynamicDutyCalculator.setCollateralRate0(collaterals, rates);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice, uint256 _rate0, uint256 _beta) = dynamicDutyCalculator.ilks(collateral);

        assertEq(_beta, beta);
        assertEq(_rate0, rate0_15p);
        assertEq(_enabled, true);
        assertEq(_lastPrice, 99500000);
    }

    function test_setCollateralRate0_price_overflow() public {
        test_setCollateralParams();
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ResilientOracle.peek.selector, lisUSD),
            abi.encode(uint256(89000000)) // returns $0.89
        );

        vm.mockCall(
            address(interaction),
            abi.encodeWithSelector(Interaction.setCollateralDuty.selector),
            abi.encode(uint256(0))
        );

        vm.startPrank(bot);
        address[] memory collaterals = new address[](1);
        collaterals[0] = collateral;
        uint256[] memory rates = new uint256[](1);
        rates[0] = rate0_15p;
        dynamicDutyCalculator.setCollateralRate0(collaterals, rates);
        vm.stopPrank();

        (bool _enabled, uint256 _lastPrice, uint256 _rate0, uint256 _beta) = dynamicDutyCalculator.ilks(collateral);

        assertEq(_beta, beta);
        assertEq(_rate0, rate0_15p);
        assertEq(_enabled, true);
        assertEq(_lastPrice, 89000000);
    }

    function test_setCollateralRate0_revert() public {
        test_setCollateralParams();

        address[] memory collaterals = new address[](1);
        collaterals[0] = collateral;
        uint256[] memory rates = new uint256[](1);
        rates[0] = rate0_15p;

        vm.startPrank(bot);
        vm.expectRevert("AMO/invalid-params");
        dynamicDutyCalculator.setCollateralRate0(collaterals, new uint256[](2));
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert("AccessControl: account 0x0000000000000000000000000000000000000001 is missing role 0x902cbe3a02736af9827fb6a90bada39e955c0941e08f0c63b3a662a7b17a4e2b");
        dynamicDutyCalculator.setCollateralRate0(collaterals, rates);
        vm.stopPrank();

        collaterals[0] = address(0);
        vm.startPrank(bot);
        vm.expectRevert("AMO/invalid-address");
        dynamicDutyCalculator.setCollateralRate0(collaterals, rates);
        vm.stopPrank();

        collaterals[0] = collateral1;
        vm.startPrank(bot);
        vm.expectRevert("AMO/invalid-status");
        dynamicDutyCalculator.setCollateralRate0(collaterals, rates);
        vm.stopPrank();
    }
}

