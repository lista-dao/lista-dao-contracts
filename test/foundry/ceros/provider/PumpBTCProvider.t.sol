// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../../contracts/interfaces/VatLike.sol";
import "../../../../contracts/ceros/ClisToken.sol";
import "../../../../contracts/ceros/CeToken.sol";
import "../../../../contracts/ceros/provider/PumpBTCProvider.sol";
import "../../../../contracts/Interaction.sol";

contract PumpBTCProviderTest is Test {
  address admin = address(0x1A11AA);
  address manager = address(0x2A11AA);
  address pauser = address(0x2A11AB);
  address user = address(0x3A11AA);
  address recipient = address(0x4A11AA);
  address proxyAdminOwner = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;

  address sender;

  uint256 mainnet;

  Interaction interaction;

  VatLike vat;

  bytes32 ilk = 0x70756d7042544300000000000000000000000000000000000000000000000000;

  IERC20 pumpBTC;

  CeToken cePumpBTC; // ceToken

  ClisToken clisPumpBTC; // lpToken

  PumpBTCProvider pumpBTCProvider;

  function setUp() public {
    sender = msg.sender;
    mainnet = vm.createSelectFork("https://bsc-dataseed.binance.org");

    vat = VatLike(0x33A34eAB3ee892D40420507B820347b1cA2201c4);
    interaction = Interaction(0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4);

    cePumpBTC = CeToken(address(new CeToken()));

    clisPumpBTC = new ClisToken();
    clisPumpBTC.initialize("clisPumpBTC", "clisPumpBTC");

    pumpBTCProvider = PumpBTCProvider(address(providerProxy));
    pumpBTCProvider = new PumpBTCProvider();
    pumpBTCProvider.initialize(
      admin,
      manager,
      pauser,
      address(clisPumpBTC),
      address(cePumpBTC),
      address(pumpBTC),
      address(interaction)
    );

    cePumpBTC.changeVault(address(pumpBTCProvider));

    vm.startPrank(admin);
    clisPumpBTC.addMinter(address(pumpBTCProvider));
    vm.stopPrank();

    vm.startPrank(proxyAdminOwner);
    interaction.setHelioProvider(address(pumpBTC), address(pumpBTCProvider), false);
    vm.stopPrank();
  }

  function test_provide() public {
    deal(address(pumpBTC), user, 123e18);

    vm.startPrank(user);
    pumpBTC.approve(address(pumpBTCProvider), 121e18);
    uint256 actual = pumpBTCProvider.provide(121e18);
    vm.stopPrank();

    assertEq(121e18, actual);
    assertEq(2e18, pumpBTC.balanceOf(user));
    assertEq(121e18, clisPumpBTC.balanceOf(user));

    (uint256 deposit, ) = vat.urns(ilk, user);
    assertEq(121e18, deposit);
  }

  /*
    function test_release_full() public {
        test_provide();

        vm.startPrank(user);
        uint256 actual = fdusdLpProvider.release(user, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(123e18, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(0, fdusdLpProvider.userLp(user));

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
        assertEq(0, fdusdLpProvider.userLp(user));

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

    function test_release_less_collateral() public {
        deal(address(FDUSD), user, 123e18);

        vm.startPrank(proxyAdminOwner);
        interaction.setHelioProvider(address(FDUSD), address(0), true);
        vm.stopPrank();

        vm.startPrank(user);
        FDUSD.approve(address(interaction), 121e18);
        interaction.deposit(user, address(FDUSD), 121e18);
        vm.stopPrank();

        assertEq(2 ether, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(0, fdusdLpProvider.userLp(user));

        (uint256 deposit0, ) = vat.urns(fdusdIlk, user);
        assertEq(121 ether, deposit0);

        vm.startPrank(proxyAdminOwner);
        interaction.setHelioProvider(address(FDUSD), address(fdusdLpProvider), false);
        vm.stopPrank();
        console.log("part 1 ok");

        vm.startPrank(user);
        uint256 actual = fdusdLpProvider.release(user, 121e18);
        vm.stopPrank();

        assertEq(121e18, actual);
        assertEq(123e18, FDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(user));

        (uint256 deposit, ) = vat.urns(fdusdIlk, user);
        assertEq(0, deposit);
    }

    function test_daoBurn() public {
        test_provide();

        vm.startPrank(address(interaction));
        vm.mockCall(address(interaction), abi.encodeWithSelector(Interaction.locked.selector), abi.encode(uint256(0)));
        fdusdLpProvider.daoBurn(user, 121e18);
        vm.stopPrank();

        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(0, fdusdLpProvider.userLp(user));
    }

    function test_daoBurn_delegated() public {
        test_provide_delegate();

        vm.startPrank(address(interaction));
        vm.mockCall(address(interaction), abi.encodeWithSelector(Interaction.locked.selector), abi.encode(uint256(0)));
        fdusdLpProvider.daoBurn(user, 121e18);
        vm.stopPrank();

        assertEq(0, clisFDUSD.balanceOf(user));
        assertEq(0, clisFDUSD.balanceOf(delegateTo));
    }
    */
}
