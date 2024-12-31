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
  address admin = address(0x10);
  address user1 = address(0x2);
  ProxyAdmin proxyAdmin = ProxyAdmin(0xBd8789025E91AF10487455B692419F82523D29Be);
  address lisUSD = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
  address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
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

    vm.expectRevert("manager cannot be zero address");
    new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        admin,
        zero,
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

    vm.expectRevert("pauser cannot be zero address");
    new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        admin,
        admin,
        zero,
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

    vm.expectRevert("token cannot be zero address");
    new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        admin,
        admin,
        admin,
        zero,
        admin,
        lisUSD,
        0,
        500,
        1e18 * 10000,
        1e18,
        1e18
      )
    );

    vm.expectRevert("feeReceiver cannot be zero address");
    new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        admin,
        admin,
        admin,
        USDC,
        zero,
        lisUSD,
        0,
        500,
        1e18 * 10000,
        1e18,
        1e18
      )
    );

    vm.expectRevert("lisUSD cannot be zero address");
    new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        admin,
        admin,
        admin,
        USDC,
        admin,
        zero,
        0,
        500,
        1e18 * 10000,
        1e18,
        1e18
      )
    );

    vm.expectRevert("sellFee must be less or equal than FEE_PRECISION");
    new ERC1967Proxy(
      address(psmImpl),
      abi.encodeWithSelector(
        psmImpl.initialize.selector,
        admin,
        admin,
        admin,
        USDC,
        admin,
        lisUSD,
        1e18,
        500,
        1e18 * 10000,
        1e18,
        1e18
      )
    );

    vm.expectRevert("buyFee must be less or equal than FEE_PRECISION");
    new ERC1967Proxy(
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
        1e18,
        1e18 * 10000,
        1e18,
        1e18
      )
    );

    vm.expectRevert("dailyLimit must be greater or equal than minBuy");
    new ERC1967Proxy(
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
        0,
        1e18,
        1e18
      )
    );
  }

  function test_setVaultManager() public {
    address zero = address(0x0);

    vm.startPrank(admin);
    vm.expectRevert("VaultManager cannot be zero address");
    psm.setVaultManager(zero);

    vm.expectRevert("VaultManager already set");
    psm.setVaultManager(address(vaultManager));
    vm.stopPrank();

    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(psm.MANAGER()), 32)
      )
    );
    psm.setVaultManager(address(vaultManager));
    vm.stopPrank();
  }

  function test_setBuyFee() public {
    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(psm.MANAGER()), 32)
      )
    );
    psm.setBuyFee(100);
    vm.stopPrank();

    vm.startPrank(admin);
    vm.expectRevert("buyFee must be less or equal than FEE_PRECISION");
    psm.setBuyFee(10001);

    psm.setBuyFee(100);
    vm.stopPrank();

    assertEq(psm.buyFee(), 100, "buyFee error");
  }

  function test_setSellFee() public {
    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(psm.MANAGER()), 32)
      )
    );
    psm.setSellFee(100);
    vm.stopPrank();

    vm.startPrank(admin);
    vm.expectRevert("sellFee must be less or equal than FEE_PRECISION");
    psm.setSellFee(10001);
    psm.setSellFee(100);
    vm.stopPrank();

    assertEq(psm.sellFee(), 100, "sellFee error");
  }

  function test_setFeeReceiver() public {
    address zero = address(0x0);

    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(psm.MANAGER()), 32)
      )
    );
    psm.setFeeReceiver(admin);
    vm.stopPrank();

    vm.startPrank(admin);
    vm.expectRevert("feeReceiver cannot be zero address");
    psm.setFeeReceiver(zero);

    psm.setFeeReceiver(admin);
    vm.stopPrank();

    assertEq(psm.feeReceiver(), admin, "set feeReceiver error");
  }

  function test_setDailyLimit() public {
    uint256 minBuy = psm.minBuy();
    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(psm.MANAGER()), 32)
      )
    );
    psm.setDailyLimit(100);
    vm.stopPrank();

    vm.startPrank(admin);
    vm.expectRevert("dailyLimit must be greater or equal than minBuy");
    psm.setDailyLimit(minBuy - 1);

    psm.setDailyLimit(minBuy + 1);
    vm.stopPrank();

    assertEq(psm.dailyLimit(), minBuy + 1, "dailyLimit error");
  }

  function test_setMinBuy() public {
    uint256 dailyLimit = psm.dailyLimit();
    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(psm.MANAGER()), 32)
      )
    );
    psm.setMinBuy(100);
    vm.stopPrank();

    vm.startPrank(admin);
    vm.expectRevert("minBuy must be less or equal than dailyLimit");
    psm.setMinBuy(dailyLimit + 1);

    psm.setMinBuy(dailyLimit);
    vm.stopPrank();

    assertEq(psm.minBuy(), dailyLimit, "minBuy error");
  }

  function test_setMinSell() public {
    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(psm.MANAGER()), 32)
      )
    );
    psm.setMinSell(100);
    vm.stopPrank();

    vm.startPrank(admin);
    psm.setMinSell(100);
    vm.stopPrank();

    assertEq(psm.minSell(), 100, "minSell error");
  }

  function test_harvest() public {
    deal(USDC, user1, 100 ether);
    deal(lisUSD, user1, 100 ether);

    uint256 feeReceiverLisUSDBalance = IERC20(lisUSD).balanceOf(admin);

    vm.startPrank(admin);
    psm.setBuyFee(100);
    psm.setSellFee(100);
    vm.stopPrank();

    vm.startPrank(user1);
    IERC20(USDC).approve(address(psm), UINT256_MAX);
    IERC20(lisUSD).approve(address(psm), UINT256_MAX);

    psm.sell(100 ether);
    assertEq(psm.fees(), 1 ether, "0 fees error");

    psm.buy(100 ether);
    assertEq(psm.fees(), 2 ether, "1 fees error");

    psm.harvest();
    assertEq(psm.fees(), 0, "2 fees error");

    assertEq(IERC20(lisUSD).balanceOf(admin), feeReceiverLisUSDBalance + 2 ether, "0 feeReceiver lisUSD balance error");
    vm.stopPrank();
  }
}
