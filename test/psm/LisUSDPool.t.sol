pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/LisUSDPoolSet.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/LisUSD.sol";

contract LisUSDPoolTest is Test {
  LisUSDPoolSet lisUSDPool;
  address admin = address(0x1);
  address user1 = address(0x2);
  ProxyAdmin proxyAdmin = ProxyAdmin(0xBd8789025E91AF10487455B692419F82523D29Be);
  address lisUSD = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
  address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
  address USDT = 0x55d398326f99059fF775485246999027B3197955;

  address lisUSDAuth = 0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253;

  uint256 MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
  uint256 MAX_DUTY = 1000000005781378656804590540;

  ProxyAdmin lisUSDProxyAdmin = ProxyAdmin(0x1Fa3E4718168077975fF4039304CC2e19Ae58c4C);

  function setUp() public {
    vm.createSelectFork("bsc-main");

    vm.deal(admin, 100 ether);
    vm.deal(user1, 100 ether);

    vm.startPrank(admin);
    LisUSDPoolSet lisUSDPoolImpl = new LisUSDPoolSet();
    ERC1967Proxy lisUSDPoolProxy = new ERC1967Proxy(
      address(lisUSDPoolImpl),
      abi.encodeWithSelector(lisUSDPoolImpl.initialize.selector, admin, admin, admin, admin, lisUSD, MAX_DUTY, 0)
    );

    lisUSDPool = LisUSDPoolSet(address(lisUSDPoolProxy));

    lisUSDPool.grantRole(lisUSDPool.BOT(), admin);
    lisUSDPool.setMaxAmount(1e18 * 1e9);
    lisUSDPool.setDuty(MAX_DUTY);
    lisUSDPool.registerPool(lisUSD, lisUSD, address(0));

    vm.stopPrank();

    vm.startPrank(lisUSDAuth);
    LisUSD lisUSDImpl = new LisUSD();
    lisUSDProxyAdmin.upgrade(ITransparentUpgradeableProxy(lisUSD), address(lisUSDImpl));

    LisUSD(lisUSD).rely(address(lisUSDPool), 1);
    vm.stopPrank();
  }

  function test_depositAndWithdraw() public {
    deal(lisUSD, user1, 100 ether);
    deal(lisUSD, admin, 10000 ether);

    address[] memory pools = new address[](1);
    pools[0] = address(lisUSD);

    vm.startPrank(admin);
    lisUSDPool.setDuty(1000000005781378656804590540);
    IERC20(lisUSD).transfer(address(lisUSDPool), 100 ether);
    vm.stopPrank();

    vm.startPrank(user1);
    IERC20(lisUSD).approve(address(lisUSDPool), MAX_UINT);

    lisUSDPool.deposit(100 ether);

    uint256 lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    uint256 poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
    uint256 userPoolEmissionWeights = lisUSDPool.poolEmissionWeights(lisUSD, user1);
    uint256 userTotalEmissionWeights = lisUSDPool.totalUserEmissionWeights(user1);

    skip(365 days);

    lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
    assertEq(lisUSDBalance, 0, "user1 lisUSD balance 1 error");
    assertEq(poolBalance, 200 ether, "pool lisUSD balance 1 error");
    assertEq(userPoolEmissionWeights, 100 ether, "user1 pool emission weights 1 error");
    assertEq(userTotalEmissionWeights, 100 ether, "user1 total emission weights 1 error");

    skip(365 days);

    uint256 lisUSDPoolBalance = lisUSDPool.assetBalanceOf(user1);
    assertEq(
      lisUSDPoolBalance,
      (100 ether * lisUSDPool.getRate()) / lisUSDPool.RATE_SCALE(),
      "user1 lisUSDPool balance 2 error"
    );
    lisUSDPool.withdraw(pools, lisUSDPoolBalance);
    lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
    userPoolEmissionWeights = lisUSDPool.poolEmissionWeights(lisUSD, user1);
    userTotalEmissionWeights = lisUSDPool.totalUserEmissionWeights(user1);
    assertEq(
      lisUSDBalance,
      (100 ether * lisUSDPool.getRate()) / lisUSDPool.RATE_SCALE(),
      "user1 lisUSD balance 2 error"
    );
    assertEq(
      poolBalance,
      200 ether - (100 ether * lisUSDPool.getRate()) / lisUSDPool.RATE_SCALE(),
      "pool lisUSD balance 2 error"
    );
    assertEq(userPoolEmissionWeights, 0, "user1 pool emission weights 2 error");
    assertEq(userTotalEmissionWeights, 0, "user1 total emission weights 2 error");

    vm.stopPrank();
  }

  function test_initialize() public {
    LisUSDPoolSet lisUSDPoolImpl = new LisUSDPoolSet();

    address zero = address(0x0);

    vm.expectRevert("admin cannot be zero address");
    new ERC1967Proxy(
      address(lisUSDPoolImpl),
      abi.encodeWithSelector(lisUSDPoolImpl.initialize.selector, zero, admin, admin, admin, lisUSD, MAX_DUTY, 0)
    );

    vm.expectRevert("manager cannot be zero address");
    new ERC1967Proxy(
      address(lisUSDPoolImpl),
      abi.encodeWithSelector(lisUSDPoolImpl.initialize.selector, admin, zero, admin, admin, lisUSD, MAX_DUTY, 0)
    );

    vm.expectRevert("pauser cannot be zero address");
    new ERC1967Proxy(
      address(lisUSDPoolImpl),
      abi.encodeWithSelector(lisUSDPoolImpl.initialize.selector, admin, admin, zero, admin, lisUSD, MAX_DUTY, 0)
    );

    vm.expectRevert("bot cannot be zero address");
    new ERC1967Proxy(
      address(lisUSDPoolImpl),
      abi.encodeWithSelector(lisUSDPoolImpl.initialize.selector, admin, admin, admin, zero, lisUSD, MAX_DUTY, 0)
    );

    vm.expectRevert("lisUSD cannot be zero address");
    new ERC1967Proxy(
      address(lisUSDPoolImpl),
      abi.encodeWithSelector(lisUSDPoolImpl.initialize.selector, admin, admin, admin, admin, zero, MAX_DUTY, 0)
    );

    assertEq(lisUSDPool.lisUSD(), lisUSD, "lisUSD error");
    assertEq(lisUSDPool.maxDuty(), MAX_DUTY, "maxDuty error");
  }

  function test_pause() public {
    vm.startPrank(user1);
    vm.expectRevert();
    lisUSDPool.pause();
    vm.stopPrank();

    vm.startPrank(admin);
    lisUSDPool.grantRole(lisUSDPool.PAUSER(), user1);
    vm.stopPrank();

    vm.startPrank(user1);
    lisUSDPool.pause();
    vm.stopPrank();

    assertTrue(lisUSDPool.paused(), "paused error");

    vm.startPrank(admin);
    lisUSDPool.unpause();
    vm.stopPrank();

    assertTrue(!lisUSDPool.paused(), "paused error");
  }

  function test_registerPool() public {
    deal(lisUSD, user1, 100 ether);
    address zero = address(0x0);

    vm.startPrank(user1);
    vm.expectRevert();
    lisUSDPool.registerPool(lisUSD, lisUSD, address(0));
    vm.stopPrank();

    vm.startPrank(admin);
    vm.expectRevert("pool cannot be zero address");
    lisUSDPool.registerPool(zero, lisUSD, address(0));
    vm.expectRevert("asset cannot be zero address");
    lisUSDPool.registerPool(lisUSD, zero, address(0));

    vm.expectRevert("pool already exists");
    lisUSDPool.registerPool(lisUSD, lisUSD, address(0));

    lisUSDPool.registerPool(USDT, USDT, address(0));

    (address asset, address distributor, bool active) = lisUSDPool.pools(USDT);
    assertTrue(active, "pool error");
    assertEq(asset, USDT, "asset error");
    assertEq(distributor, address(0), "distributor error");

    lisUSDPool.removePool(lisUSD);

    (asset, distributor, active) = lisUSDPool.pools(lisUSD);
    assertTrue(!active, "pool error");
    vm.stopPrank();

    vm.startPrank(user1);
    IERC20(lisUSD).approve(address(lisUSDPool), MAX_UINT);
    vm.expectRevert("pool not active");
    lisUSDPool.deposit(10 ether);
    vm.stopPrank();
  }

  function test_setMaxAmount() public {
    deal(lisUSD, user1, 100 ether);

    vm.startPrank(user1);
    vm.expectRevert();
    lisUSDPool.setMaxAmount(1e18 * 1e9);
    vm.stopPrank();

    vm.startPrank(admin);
    lisUSDPool.setMaxAmount(1e18);

    assertEq(lisUSDPool.maxAmount(), 1e18, "maxAmount error");
    vm.stopPrank();

    vm.startPrank(user1);
    IERC20(lisUSD).approve(address(lisUSDPool), MAX_UINT);
    vm.expectRevert("exceed max amount");
    lisUSDPool.deposit(10 ether);
    vm.stopPrank();
  }

  function test_withdrawAll() public {
    deal(lisUSD, user1, 1000 ether);
    deal(lisUSD, admin, 1000 ether);

    vm.startPrank(admin);
    lisUSDPool.setWithdrawDelay(5);
    IERC20(lisUSD).transfer(address(lisUSDPool), 1000 ether);
    vm.stopPrank();

    address[] memory pools = new address[](1);
    pools[0] = lisUSD;

    vm.startPrank(user1);
    IERC20(lisUSD).approve(address(lisUSDPool), MAX_UINT);
    lisUSDPool.deposit(100 ether);
    vm.expectRevert("withdraw delay not reached");
    lisUSDPool.withdraw(pools, 100 ether);

    skip(5);
    lisUSDPool.withdraw(pools, 100 ether);
    uint256 lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    assertEq(lisUSDBalance, 1000 ether, "user1 lisUSD balance 1 error");

    uint256 asset = lisUSDPool.assetBalanceOf(user1);
    lisUSDPool.withdrawAll(pools);
    lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    assertEq(lisUSDBalance - asset, 1000 ether, "user1 lisUSD balance 2 error");
    vm.stopPrank();
  }
}
