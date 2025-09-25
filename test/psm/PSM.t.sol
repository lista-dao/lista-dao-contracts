pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/psm/VenusAdapter.sol";
import "../../contracts/interfaces/IVBep20Delegate.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract PSMTest is Test {
  PSM psm;
  VaultManager vaultManager;
  VenusAdapter venusAdapter;
  MockERC20PSM usdcToken;
  MockERC20PSM lisUSDToken;
  MockVBep20PSM vUsdcToken;
  address admin = address(0x10);
  address user1 = address(0x2);
  address USDC;
  address lisUSD;
  address vUSDC;

  uint256 constant MAX_UINT = type(uint256).max;

  function setUp() public {
    vm.deal(admin, 100 ether);
    vm.deal(user1, 100 ether);

    usdcToken = new MockERC20PSM("Mock USDC", "mUSDC");
    lisUSDToken = new MockERC20PSM("Mock LisUSD", "mLisUSD");
    vUsdcToken = new MockVBep20PSM(IERC20(address(usdcToken)));

    USDC = address(usdcToken);
    lisUSD = address(lisUSDToken);
    vUSDC = address(vUsdcToken);

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
        admin
      )
    );

    venusAdapter = VenusAdapter(address(venusAdapterProxy));

    vaultManager.addAdapter(address(venusAdapter), 100);

    vm.stopPrank();

    lisUSDToken.mint(admin, 1000000 ether);
    vm.prank(admin);
    lisUSDToken.transfer(address(psm), 10000 ether);
  }

  function test_depositAndWithdraw() public {
    usdcToken.mint(user1, 1000 ether);

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
    usdcToken.mint(user1, 100 ether);
    lisUSDToken.mint(user1, 100 ether);

    uint256 feeReceiverLisUSDBalance = IERC20(lisUSD).balanceOf(admin);

    vm.startPrank(admin);
    psm.setBuyFee(100);
    psm.setSellFee(100);
    vm.stopPrank();

    vm.startPrank(user1);
    IERC20(USDC).approve(address(psm), MAX_UINT);
    IERC20(lisUSD).approve(address(psm), MAX_UINT);

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

contract MockERC20PSM is ERC20 {
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}

contract MockVBep20PSM is ERC20("Mock vToken", "mvToken"), IVBep20Delegate {
  using Math for uint256;

  IERC20 public immutable underlying;
  uint256 public exchangeRate = 1e18;

  constructor(IERC20 underlying_) {
    underlying = underlying_;
  }

  function setExchangeRate(uint256 newRate) external {
    require(newRate > 0, "exchange rate zero");
    exchangeRate = newRate;
  }

  function mint(uint256 mintAmount) external override returns (uint256) {
    require(mintAmount > 0, "mint amount zero");
    underlying.transferFrom(msg.sender, address(this), mintAmount);

    uint256 shares = Math.mulDiv(mintAmount, 1e18, exchangeRate);
    require(shares > 0, "shares zero");
    _mint(msg.sender, shares);
    return 0;
  }

  function redeem(uint256 redeemTokens) external override returns (uint256) {
    require(redeemTokens > 0, "redeem tokens zero");
    uint256 underlyingAmount = Math.mulDiv(redeemTokens, exchangeRate, 1e18);
    _burn(msg.sender, redeemTokens);
    underlying.transfer(msg.sender, underlyingAmount);
    return 0;
  }

  function redeemUnderlying(uint256 redeemAmount) external override returns (uint256) {
    require(redeemAmount > 0, "redeem amount zero");
    uint256 shares = Math.mulDiv(redeemAmount, 1e18, exchangeRate);
    if (Math.mulDiv(shares, exchangeRate, 1e18) < redeemAmount) {
      shares += 1;
    }
    require(balanceOf(msg.sender) >= shares, "insufficient shares");
    _burn(msg.sender, shares);
    underlying.transfer(msg.sender, redeemAmount);
    return 0;
  }

  function balanceOfUnderlying(address owner) external view override returns (uint256) {
    return Math.mulDiv(balanceOf(owner), exchangeRate, 1e18);
  }
}
