pragma solidity ^0.8.10;

import "../../contracts/LisUSD.sol";
import "../../contracts/hMath.sol";
import "../../contracts/psm/LisUSDPoolSet.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/psm/VenusAdapter.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Test.sol";

contract PSMTest is Test {
  PSM psm;
  VaultManager vaultManager;
  VenusAdapter venusAdapter;
  address admin = address(0x1);
  address user1 = address(0x2);
  ProxyAdmin proxyAdmin = ProxyAdmin(0xBd8789025E91AF10487455B692419F82523D29Be);
  address lisUSD = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
  address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
  address venusPool = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
  address vUSDC = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
  uint256 quotaAmount = 1e18;

  address lisUSDAuth = 0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37;

  uint256 MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

  function setUp() public {
    vm.createSelectFork("bsc-main");

    vm.deal(admin, 100 ether);
    vm.deal(user1, 100 ether);

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
        500,
        1e18 * 1e7,
        1e18,
        1e18
      )
    );

    psm = PSM(address(psmProxy));

    VaultManager vaultManagerImpl = new VaultManager();

    ERC1967Proxy vaultManagerProxy = new ERC1967Proxy(
      address(vaultManagerImpl),
      abi.encodeWithSelector(vaultManagerImpl.initialize.selector, admin, admin, address(psm), USDC)
    );

    vaultManager = VaultManager(address(vaultManagerProxy));

    psm.setVaultManager(address(vaultManager));

    VenusAdapter venusAdapterImpl = new VenusAdapter();

    ERC1967Proxy venusAdapterProxy = new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        admin,
        admin,
        address(vaultManager),
        venusPool,
        USDC,
        vUSDC,
        quotaAmount,
        admin
      )
    );

    venusAdapter = VenusAdapter(address(venusAdapterProxy));

    vaultManager.addAdapter(address(venusAdapter), 100);

    vm.stopPrank();

    deal(lisUSD, admin, 1000000 ether);
    vm.startPrank(admin);
    IERC20(lisUSD).transfer(address(psm), 10000 ether);
    vm.stopPrank();
  }

  function test_depositAndWithdraw() public {
    deal(USDC, user1, 1000 ether);

    vm.startPrank(user1);
    IERC20(USDC).approve(address(psm), MAX_UINT);
    IERC20(lisUSD).approve(address(psm), MAX_UINT);

    psm.sell(100 ether);

    uint256 usdcBalance = IERC20(USDC).balanceOf(user1);
    uint256 lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    assertEq(usdcBalance, 900 ether, "user1 USDC balance 0 error");
    assertEq(lisUSDBalance, 100 ether, "user1 lisUSD balance 0 error");

    psm.buy(100 ether);

    usdcBalance = IERC20(USDC).balanceOf(user1);
    lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
    assertEq(usdcBalance, 995 ether, "user1 USDC balance 1 error");
    assertEq(lisUSDBalance, 0, "user1 lisUSD balance 1 error");

    vm.stopPrank();
  }

  function test_initialize() public {
    address zero = address(0x0);
    PSM psmImpl = new PSM();

    vm.expectRevert("admin cannot be zero address");
    new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        zero,
        admin,
        admin,
        USDC,
        admin,
        lisUSD,
        0,
        500,
        1e18 * 10000,
        1e18,
        1e18
      )
    );
  }
}
