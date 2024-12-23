// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../../contracts/interfaces/VatLike.sol";
import "../../../../contracts/interfaces/GemJoinLike.sol";
import "../../../../contracts/ceros/ClisToken.sol";
import "../../../../contracts/ceros/CeToken.sol";
import "../../../../contracts/ceros/provider/PumpBTCProvider.sol";
import "../../../../contracts/Interaction.sol";

import { Clipper } from "../../../../contracts/clip.sol";
import { Spotter } from "../../../../contracts/spot.sol";
import { GemJoin } from "../../../../contracts/join.sol";
import { Dog } from "../../../../contracts/dog.sol";
import { BtcOracle } from "../../../../contracts/oracle/BtcOracle.sol";

import { ERC20UpgradeableMock } from "../../../../contracts/mock/ERC20UpgradeableMock.sol";

contract PumpBTCProviderTest is Test {
  address admin = address(0x1A11AA);
  address manager = address(0x2A11AA);
  address pauser = address(0x2A11AB);
  address user = address(0x3A11AA);

  address wards = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
  address auth = 0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37;

  bytes32 ilk = 0x70756d7042544300000000000000000000000000000000000000000000000000;
  uint mat = 2000000000000000000000000000;

  Interaction interaction;
  GemJoin gemJoin;
  Clipper clip;
  VatLike vat;
  Spotter spotter;
  Dog dog;

  BtcOracle oracle;

  ERC20UpgradeableMock pumpBTC;

  CeToken cePumpBTC; // ceToken

  ClisToken clisPumpBTC; // lpToken

  PumpBTCProvider pumpBTCProvider;

  function setUp() public {
    //sender = msg.sender;
    vm.createSelectFork("https://bsc-dataseed.binance.org");

    vat = VatLike(0x33A34eAB3ee892D40420507B820347b1cA2201c4);
    spotter = Spotter(0x49bc2c4E5B035341b7d92Da4e6B267F7426F3038);
    interaction = Interaction(0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4);
    dog = Dog(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    oracle = BtcOracle(0x2eeDc4723b1ED2f24afCD9c0e3665061bD2D5642);

    // token
    pumpBTC = new ERC20UpgradeableMock();
    pumpBTC.initialize("pumpBTC", "pumpBTC");

    // ceToken
    cePumpBTC = new CeToken();
    cePumpBTC.initialize("cePumpBTC", "cePumpBTC");

    // lpToken
    clisPumpBTC = new ClisToken();
    clisPumpBTC.initialize("clisPumpBTC", "clisPumpBTC");

    // provider
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

    // deploy gemJoin
    gemJoin = new GemJoin();
    gemJoin.initialize(address(vat), ilk, address(cePumpBTC));

    // gemJoin: rely on interaction
    gemJoin.rely(address(interaction));

    // deploy clip
    clip = new Clipper();
    clip.initialize(address(vat), address(spotter), address(dog), ilk);

    // ceToken: set provider as minter
    cePumpBTC.changeVault(address(pumpBTCProvider));

    // lpToken: set provider as minter
    clisPumpBTC.addMinter(address(pumpBTCProvider));

    vm.startPrank(auth);
    // vat: rely on clip
    vat.rely(address(clip));
    // vat: rely on gemJoin
    vat.rely(address(gemJoin));
    // vat: set ceiling for ilk
    vat.file(ilk, "line", 50000000000000000000000000000000000000000000000000);
    // spotter: configure oracle
    spotter.file(ilk, "pip", address(oracle));
    vm.stopPrank();

    vm.startPrank(wards);
    // interaction: set provider of cePumpBTC
    interaction.setHelioProvider(address(cePumpBTC), address(pumpBTCProvider), false);

    interaction.setCollateralType(address(cePumpBTC), address(gemJoin), ilk, address(clip), mat);
    vm.stopPrank();
  }

  function test_provide() public {
    uint scale = pumpBTCProvider.scale();
    uint amount = 2 * 1e8; // 2 pumpBTC
    deal(address(pumpBTC), user, amount);

    vm.startPrank(user);
    uint amt1 = amount / 2;
    pumpBTC.approve(address(pumpBTCProvider), amt1);
    uint256 lpAmount = pumpBTCProvider.provide(amt1);
    vm.stopPrank();

    assertEq(lpAmount, amt1 * scale);
    assertEq(pumpBTC.balanceOf(user), 1e8);
    assertEq(pumpBTC.balanceOf(address(pumpBTCProvider)), 1e8);
    assertEq(clisPumpBTC.balanceOf(user), lpAmount);
    assertEq(cePumpBTC.balanceOf(user), 0);
    assertEq(cePumpBTC.balanceOf(address(gemJoin)), lpAmount);
    assertEq(cePumpBTC.totalSupply(), lpAmount);

    (uint256 deposit, ) = vat.urns(ilk, user);
    assertEq(deposit, lpAmount);
  }

  function test_release_full() public {
    test_provide();
    uint amt1 = 1e8; // 1 pumpBTC

    vm.startPrank(user);
    uint256 tokenAmount = pumpBTCProvider.release(user, amt1);
    vm.stopPrank();

    assertEq(tokenAmount, amt1);
    assertEq(pumpBTC.balanceOf(user), 2e8);
    assertEq(pumpBTC.balanceOf(address(pumpBTCProvider)), 0);
    assertEq(clisPumpBTC.balanceOf(user), 0);
    assertEq(cePumpBTC.balanceOf(user), 0);
    assertEq(cePumpBTC.balanceOf(address(gemJoin)), 0);
    assertEq(cePumpBTC.totalSupply(), 0);

    (uint256 deposit, ) = vat.urns(ilk, user);
    assertEq(deposit, 0);
  }

  function test_release_partial() public {
    test_provide();
    uint amt2 = 5e7; // 0.5 pumpBTC

    vm.startPrank(user);
    uint256 tokenAmount = pumpBTCProvider.release(user, amt2);
    vm.stopPrank();

    assertEq(tokenAmount, amt2);
    assertEq(pumpBTC.balanceOf(user), 1e8 + amt2);
    assertEq(pumpBTC.balanceOf(address(pumpBTCProvider)), amt2);
    assertEq(clisPumpBTC.balanceOf(user), amt2 * pumpBTCProvider.scale());
    assertEq(cePumpBTC.balanceOf(user), 0);
    assertEq(cePumpBTC.balanceOf(address(gemJoin)), amt2 * pumpBTCProvider.scale());
    assertEq(cePumpBTC.totalSupply(), amt2 * pumpBTCProvider.scale());

    (uint256 deposit, ) = vat.urns(ilk, user);
    assertEq(deposit, amt2 * pumpBTCProvider.scale());
  }

  function test_borrow() public {
    test_provide();
    uint amt2 = 5e7; // 0.5 pumpBTC

    uint lisusd = 100 * 1e18; // 100 lisusd

    vm.startPrank(user);
    interaction.borrow(address(cePumpBTC), lisusd);

    uint256 tokenAmount = pumpBTCProvider.release(user, amt2);
    vm.stopPrank();

    assertEq(tokenAmount, amt2);
    assertEq(pumpBTC.balanceOf(user), 1e8 + amt2);
    assertEq(pumpBTC.balanceOf(address(pumpBTCProvider)), amt2);
    assertEq(clisPumpBTC.balanceOf(user), amt2 * pumpBTCProvider.scale());
    assertEq(cePumpBTC.balanceOf(user), 0);
    assertEq(cePumpBTC.balanceOf(address(gemJoin)), amt2 * pumpBTCProvider.scale());
    assertEq(cePumpBTC.totalSupply(), amt2 * pumpBTCProvider.scale());

    (uint256 deposit, ) = vat.urns(ilk, user);
    assertEq(deposit, amt2 * pumpBTCProvider.scale());
  }

  function test_daoBurn() public {
    test_provide();

    vm.startPrank(address(interaction));
    vm.mockCall(address(interaction), abi.encodeWithSelector(Interaction.locked.selector), abi.encode(uint256(0)));
    pumpBTCProvider.daoBurn(user, 1e8 * pumpBTCProvider.scale());
    vm.stopPrank();

    assertEq(pumpBTC.balanceOf(user), 1e8);
    assertEq(pumpBTC.balanceOf(address(pumpBTCProvider)), 1e8);

    assertEq(clisPumpBTC.balanceOf(user), 0);
    assertEq(cePumpBTC.balanceOf(user), 0);
    assertEq(cePumpBTC.balanceOf(address(gemJoin)), 1e8 * pumpBTCProvider.scale());

    assertEq(cePumpBTC.totalSupply(), 1e8 * pumpBTCProvider.scale());
    assertEq(clisPumpBTC.totalSupply(), 0);
  }
}
