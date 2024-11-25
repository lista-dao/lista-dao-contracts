pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/LisUSDPoolSet.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/LisUSD.sol";
import "../../contracts/psm/EarnPool.sol";

contract EarnPoolTest is Test {
  PSM psm;
  VaultManager vaultManager;
  LisUSDPoolSet lisUSDPool;
  EarnPool earnPool;
  address admin = address(0x1);
  address user1 = address(0x2);
  address lisUSD = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
  address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
  uint256 MAX_DUTY = 1000000005781378656804590540;
  uint256 duty = 1000000005781378656804590540;
  address USDT = 0x55d398326f99059fF775485246999027B3197955;

  address lisUSDAuth = 0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253;

  uint256 MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

  ProxyAdmin lisUSDProxyAdmin = ProxyAdmin(0x1Fa3E4718168077975fF4039304CC2e19Ae58c4C);

  function setUp() public {
    vm.createSelectFork("bsc-main");

    vm.deal(admin, 100 ether);
    vm.deal(user1, 100 ether);
    deal(lisUSD, admin, 10000000 ether);

    vm.startPrank(admin);
    PSM psmImpl = new PSM();

    ERC1967Proxy psmProxy = new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        admin,
        admin,
        admin,
        USDC,
        admin,
        lisUSD,
        0,
        0,
        1e18 * 1e7,
        1e18,
        1e18
      )
    );

    psm = PSM(address(psmProxy));

    VaultManager vaultManagerImpl = new VaultManager();

    ERC1967Proxy vaultManagerProxy = new ERC1967Proxy(
      address(vaultManagerImpl),
      abi.encodeWithSelector(vaultManagerImpl.initialize.selector, admin, admin, address(psm), USDC, admin)
    );

    vaultManager = VaultManager(address(vaultManagerProxy));

    psm.setVaultManager(address(vaultManager));

    LisUSDPoolSet lisUSDPoolImpl = new LisUSDPoolSet();
    ERC1967Proxy lisUSDPoolProxy = new ERC1967Proxy(
      address(lisUSDPoolImpl),
      abi.encodeWithSelector(lisUSDPoolImpl.initialize.selector, admin, admin, admin, admin, lisUSD, MAX_DUTY, 0)
    );

    lisUSDPool = LisUSDPoolSet(address(lisUSDPoolProxy));

    EarnPool earnPoolImpl = new EarnPool();
    ERC1967Proxy earnPoolProxy = new ERC1967Proxy(
      address(earnPoolImpl),
      abi.encodeWithSelector(earnPoolImpl.initialize.selector, admin, admin, admin, address(lisUSDPool), lisUSD)
    );
    earnPool = EarnPool(address(earnPoolProxy));

    earnPool.setPSM(USDC, address(psm));

    lisUSDPool.grantRole(lisUSDPool.BOT(), admin);
    lisUSDPool.setEarnPool(address(earnPool));
    lisUSDPool.registerPool(USDC, USDC, address(0));
    lisUSDPool.setDuty(duty);
    lisUSDPool.setMaxAmount(1e18 * 1e9);

    vm.stopPrank();

    vm.startPrank(lisUSDAuth);
    LisUSD lisUSDImpl = new LisUSD();
    lisUSDProxyAdmin.upgrade(ITransparentUpgradeableProxy(lisUSD), address(lisUSDImpl));

    LisUSD(lisUSD).rely(address(psm), 1);
    LisUSD(lisUSD).rely(address(lisUSDPool), 1);
    vm.stopPrank();

    vm.startPrank(admin);
    IERC20(lisUSD).transfer(address(psm), 1000000 ether);
    vm.stopPrank();
  }

  function test_initialize() public {
    EarnPool earnPoolImpl = new EarnPool();

    address zero = address(0x0);

    vm.expectRevert("admin cannot be zero address");
    new ERC1967Proxy(
      address(earnPoolImpl),
      abi.encodeWithSelector(earnPoolImpl.initialize.selector, zero, admin, admin, address(lisUSDPool), lisUSD)
    );

    vm.expectRevert("manager cannot be zero address");
    new ERC1967Proxy(
      address(earnPoolImpl),
      abi.encodeWithSelector(earnPoolImpl.initialize.selector, admin, zero, admin, address(lisUSDPool), lisUSD)
    );

    vm.expectRevert("pauser cannot be zero address");
    new ERC1967Proxy(
      address(earnPoolImpl),
      abi.encodeWithSelector(earnPoolImpl.initialize.selector, admin, admin, zero, admin, address(lisUSDPool), lisUSD)
    );
    vm.expectRevert("lisUSDPool cannot be zero address");
    new ERC1967Proxy(
      address(earnPoolImpl),
      abi.encodeWithSelector(earnPoolImpl.initialize.selector, admin, admin, admin, zero, lisUSD)
    );
    vm.expectRevert("lisUSD cannot be zero address");
    new ERC1967Proxy(
      address(earnPoolImpl),
      abi.encodeWithSelector(earnPoolImpl.initialize.selector, admin, admin, admin, address(lisUSDPool), zero)
    );

    assertEq(earnPool.lisUSDPool(), address(lisUSDPool), "lisUSDPool set error");
    assertEq(earnPool.lisUSD(), lisUSD, "lisUSD set error");
  }

  function test_role() public {
    EarnPool earnPoolImpl = new EarnPool();

    ERC1967Proxy earnPoolProxy = new ERC1967Proxy(
      address(earnPoolImpl),
      abi.encodeWithSelector(earnPoolImpl.initialize.selector, admin, admin, admin, address(lisUSDPool), lisUSD)
    );

    EarnPool earnPool = EarnPool(address(earnPoolProxy));

    assertTrue(earnPool.hasRole(earnPool.DEFAULT_ADMIN_ROLE(), admin), "admin role error");
    assertTrue(earnPool.hasRole(earnPool.MANAGER(), admin), "manager role error");
    assertTrue(earnPool.hasRole(earnPool.PAUSER(), admin), "pauser role error");
    assertTrue(!earnPool.hasRole(earnPool.PAUSER(), user1), "pauser role error");

    vm.startPrank(admin);
    earnPool.grantRole(earnPool.PAUSER(), user1);
    vm.stopPrank();

    assertTrue(earnPool.hasRole(earnPool.PAUSER(), user1), "pauser role error");
  }

  function test_pause() public {
    vm.startPrank(user1);
    vm.expectRevert();
    earnPool.pause();
    vm.stopPrank();

    vm.startPrank(admin);
    earnPool.grantRole(earnPool.PAUSER(), user1);
    vm.stopPrank();

    vm.startPrank(user1);
    earnPool.pause();
    vm.stopPrank();

    assertTrue(earnPool.paused(), "paused error");

    vm.startPrank(admin);
    earnPool.unpause();
    vm.stopPrank();

    assertTrue(!earnPool.paused(), "paused error");
  }

  function test_setPSM() public {
    PSM psmImpl = new PSM();

    ERC1967Proxy psmProxy = new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        admin,
        admin,
        admin,
        USDT,
        admin,
        lisUSD,
        0,
        0,
        1e18 * 1e7,
        1e18,
        1e18
      )
    );
    address usdtPSM = address(psmProxy);
    address zero = address(0x0);

    vm.startPrank(user1);
    vm.expectRevert();
    earnPool.setPSM(USDT, address(usdtPSM));
    vm.stopPrank();

    vm.startPrank(admin);
    vm.expectRevert("token cannot be zero address");
    earnPool.setPSM(zero, address(usdtPSM));
    vm.expectRevert("psm cannot be zero address");
    earnPool.setPSM(USDT, zero);
    vm.expectRevert("psm already set");
    earnPool.setPSM(USDC, address(psm));
    vm.expectRevert("psm token not match");
    earnPool.setPSM(USDT, address(psm));

    earnPool.setPSM(USDT, address(usdtPSM));
    assertEq(earnPool.psm(USDT), address(usdtPSM), "psm set error");

    earnPool.removePSM(USDT);
    assertEq(earnPool.psm(USDT), address(0), "psm remove error");
    vm.stopPrank();
  }

  function test_depositAndWithdraw() public {
    deal(USDC, user1, 1000 ether);
    deal(lisUSD, user1, 1000 ether);

    address[] memory pools = new address[](2);
    pools[0] = address(USDC);
    pools[1] = address(lisUSD);

    vm.startPrank(admin);
    IERC20(lisUSD).transfer(address(lisUSDPool), 100 ether);
    vm.stopPrank();

    vm.startPrank(user1);
    IERC20(USDC).approve(address(earnPool), MAX_UINT);
    IERC20(lisUSD).approve(address(earnPool), MAX_UINT);

    earnPool.deposit(USDC, 100 ether);

    uint256 usdcBalance = IERC20(USDC).balanceOf(user1);
    uint256 lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    assertEq(usdcBalance, 900 ether, "user1 USDC 0 error");
    assertEq(lisUSDBalance, 1000 ether, "user1 lisUSD 0 error");
    assertEq(IERC20(lisUSD).balanceOf(address(lisUSDPool)), 200 ether, "lisUSDPool lisUSD balance 0 error");

    skip(1 days);
    lisUSDPool.withdraw(pools, 1 ether);
    usdcBalance = IERC20(USDC).balanceOf(user1);
    lisUSDBalance = IERC20(lisUSD).balanceOf(user1);

    uint256 earnPoolBalance = lisUSDPool.poolEmissionWeights(address(USDC), user1);
    uint256 totalEmission = lisUSDPool.totalUserEmissionWeights(user1);
    assertEq(earnPoolBalance, 99 ether, "user1 earnPool balance 1 error");
    assertEq(usdcBalance, 900 ether, "user1 USDC 1 error");
    assertEq(lisUSDBalance, 1001 ether, "user1 lisUSD 1 error");
    assertEq(totalEmission, 99 ether, "user1 totalEmission 1 error");

    lisUSDPool.withdraw(pools, 99 ether);

    usdcBalance = IERC20(USDC).balanceOf(user1);
    lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    earnPoolBalance = lisUSDPool.poolEmissionWeights(address(USDC), user1);
    totalEmission = lisUSDPool.totalUserEmissionWeights(user1);
    assertEq(earnPoolBalance, 0, "user1 earnPool balance 2 error");
    assertEq(usdcBalance, 900 ether, "user1 USDC 2 error");
    assertEq(lisUSDBalance, 1100 ether, "user1 lisUSD 2 error");
    assertEq(totalEmission, 0, "user1 totalEmission 2 error");

    vm.stopPrank();
  }
}
