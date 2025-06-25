// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../contracts/CDPLiquidator.sol";
import "./mocks/MockOneInch.sol";
import "../../contracts/Interaction.sol";
import { Clipper } from "../../contracts/clip.sol";

contract CDPLiquidatorTest is Test {
    address lender = 0x64d94e715B6c03A5D8ebc6B2144fcef278EC6aAa;
    Interaction interaction = Interaction(0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4);
    address lisUSD = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
    address BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address btcOracle = 0x2eeDc4723b1ED2f24afCD9c0e3665061bD2D5642;
    Clipper clipper = Clipper(0xb12fF6FD1885a9Cb2b26302c98092644604B1e92);
    ProxyAdmin clipperProxyAdmin = ProxyAdmin(0x7ddA90bE4a21790bc21e4F6479C03607ef8a4716);
    address clipperAdmin = 0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253;

    address bot = 0x08E83A96F4dA5DecC0e6E9084dDe049A3E84ca04;
    address operator = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
    address borrower;
    address admin;
    address manager;

    MockOneInch oneInch;

    CDPLiquidator liquidator;
    function setUp() public {
        vm.createSelectFork("https://bsc-dataseed.bnbchain.org");

        borrower = makeAddr("borrower");
        admin = makeAddr("admin");
        manager = makeAddr("manager");

        CDPLiquidator liquidatorImpl = new CDPLiquidator();
        ERC1967Proxy liquidatorProxy = new ERC1967Proxy(
            address(liquidatorImpl),
            abi.encodeWithSelector(
                liquidatorImpl.initialize.selector,
                admin,
                manager,
                bot,
                IERC3156FlashLender(lender),
                IInteraction(address(interaction)),
                lisUSD
            )
        );

        liquidator = CDPLiquidator(address(liquidatorProxy));

        oneInch = new MockOneInch();

        vm.startPrank(manager);
        liquidator.setTokenWhitelist(BTCB, true);
        liquidator.setPairWhitelist(address(oneInch), true);
        vm.stopPrank();

        vm.startPrank(operator);
        address[] memory whitelist = new address[](1);
        whitelist[0] = address(liquidator);
        interaction.addToAuctionWhitelist(whitelist);
        vm.stopPrank();

    }

    function test_flashLiquidate() public {
        deal(BTCB, borrower, 1 ether);
        vm.mockCall(btcOracle, abi.encodeWithSignature("peek()"), abi.encode(bytes32(uint256(100_000 ether)), true));

        uint256 collateralAmount = 0.01 ether;

        uint256 borrowAmount = borrowAll(borrower, BTCB, collateralAmount);

        vm.mockCall(btcOracle, abi.encodeWithSignature("peek()"), abi.encode(bytes32(uint256(99_000 ether)), true));

        vm.startPrank(bot);
        uint256 auctionId = interaction.startAuction(BTCB, borrower, bot);

        skip(600);

        (,uint256 price,uint256 lot,uint256 tab) = clipper.getStatus(auctionId);
        uint256 chost = clipper.chost();

        uint256 collateralAmt = (tab - chost) / price;

        liquidator.flashLiquidate(
            auctionId,
            10000 ether,
            BTCB,
            collateralAmt,
            price,
            BTCB,
            address(oneInch),
            abi.encodeWithSelector(
                oneInch.swap.selector,
                BTCB,
                lisUSD,
                collateralAmt,
                collateralAmt * 99_000 ether / 1 ether
            )
        );
        vm.stopPrank();

        uint256 profit = IERC20(lisUSD).balanceOf(address(liquidator));
        assertGt(profit, 0, "Profit should be greater than zero");
    }

    function test_liquidate() public {
        deal(lisUSD, address(liquidator), 10000 ether);
        deal(BTCB, borrower, 1 ether);
        vm.mockCall(btcOracle, abi.encodeWithSignature("peek()"), abi.encode(bytes32(uint256(100_000 ether)), true));

        uint256 collateralAmount = 0.01 ether;

        uint256 borrowAmount = borrowAll(borrower, BTCB, collateralAmount);

        vm.mockCall(btcOracle, abi.encodeWithSignature("peek()"), abi.encode(bytes32(uint256(99_000 ether)), true));

        vm.startPrank(bot);
        uint256 auctionId = interaction.startAuction(BTCB, borrower, bot);

        skip(600);

        (,uint256 price,,) = clipper.getStatus(auctionId);

        liquidator.liquidate(
            auctionId,
            BTCB,
            0.01 ether,
            price
        );
        vm.stopPrank();

        uint256 liquidationCollateralAmount = IERC20(BTCB).balanceOf(address(liquidator));
        assertGt(liquidationCollateralAmount, 0, "liquidationCollateralAmount should be greater than zero");
    }

    function test_sellToken() public {
        deal(BTCB, address(liquidator), 1 ether);

        uint256 inAmount = 1 ether;
        uint256 outAmount = 100_000 ether;

        vm.startPrank(bot);
        liquidator.sellToken(
            address(oneInch),
            BTCB,
            inAmount,
            outAmount,
            abi.encodeWithSelector(
                oneInch.swap.selector,
                BTCB,
                lisUSD,
                inAmount,
               outAmount
            )
        );
        vm.stopPrank();

        assertEq(IERC20(lisUSD).balanceOf(address(liquidator)), outAmount, "loanToken balance");
        assertEq(IERC20(BTCB).balanceOf(address(liquidator)), 0, "collateralToken balance");
    }

    function borrowAll(address user, address collateral, uint256 collateralAmount) internal returns (uint256 amount) {

        interaction.drip(collateral);
        interaction.poke(collateral);

        vm.startPrank(user);

        IERC20(collateral).approve(address(interaction), collateralAmount);
        interaction.deposit(user, collateral, collateralAmount);
        int256 borrowAmount = interaction.availableToBorrow(collateral, user);

        uint256 before = IERC20(lisUSD).balanceOf(user);
        interaction.borrow(collateral, uint256(borrowAmount - 1));
        uint256 actualAmount = IERC20(lisUSD).balanceOf(user) - before;

        vm.stopPrank();

        return actualAmount;
    }

}