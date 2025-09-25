pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/psm/VenusAdapter.sol";
import "../../contracts/interfaces/IVBep20Delegate.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract VaultManagerTest is Test {
  VaultManager vaultManager;
  VenusAdapter venusAdapter;
  MockERC20VM usdc;
  MockVBep20VM vUsdc;
  address admin = address(0x10);
  address user1 = address(0x2);

  uint256 constant MAX_UINT = type(uint256).max;

  function setUp() public {
    vm.deal(admin, 100 ether);
    vm.deal(user1, 100 ether);

    usdc = new MockERC20VM("Mock USDC", "mUSDC");
    vUsdc = new MockVBep20VM(IERC20(address(usdc)));

    vm.startPrank(admin);

    VaultManager vaultManagerImpl = new VaultManager();

    ERC1967Proxy vaultManagerProxy = new ERC1967Proxy(
      address(vaultManagerImpl),
      abi.encodeWithSelector(vaultManagerImpl.initialize.selector, admin, admin, address(user1), address(usdc))
    );

    vaultManager = VaultManager(address(vaultManagerProxy));

    VenusAdapter venusAdapterImpl = new VenusAdapter();

    ERC1967Proxy venusAdapterProxy = new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        admin,
        admin,
        address(vaultManager),
        address(usdc),
        address(vUsdc),
        admin
      )
    );

    venusAdapter = VenusAdapter(address(venusAdapterProxy));

    vm.stopPrank();
  }

  function test_depositAndWithdraw() public {
    usdc.mint(user1, 1000 ether);

    vm.startPrank(admin);
    vaultManager.addAdapter(address(venusAdapter), 100);
    vm.stopPrank();

    vm.startPrank(user1);
    usdc.approve(address(vaultManager), MAX_UINT);

    vaultManager.deposit(100 ether);

    uint256 usdcBalance = usdc.balanceOf(user1);
    assertEq(usdcBalance, 900 ether, "user1 USDC 0 error");

    vaultManager.withdraw(user1, 99 ether);
    usdcBalance = usdc.balanceOf(user1);
    assertEq(usdcBalance, 999 ether, "user1 USDC 1 error");
    vm.stopPrank();
  }

  function test_addAdapter() public {
    usdc.mint(user1, 1000 ether);

    vm.startPrank(admin);
    vaultManager.addAdapter(address(venusAdapter), 1000);
    vm.stopPrank();

    vm.startPrank(user1);
    usdc.approve(address(vaultManager), MAX_UINT);

    vaultManager.deposit(1000 ether);

    uint256 venusAdapterBalance = IVBep20Delegate(address(vUsdc)).balanceOfUnderlying(address(venusAdapter));
    uint256 vaultManagerBalance = usdc.balanceOf(address(vaultManager));
    assertTrue(venusAdapterBalance <= 1000 ether && venusAdapterBalance > 999 ether, "venusAdapterBalance 0 error");
    assertEq(vaultManagerBalance, 0, "vaultManagerBalance 0 error");

    vaultManager.withdraw(user1, 900 ether);
    venusAdapterBalance = IVBep20Delegate(address(vUsdc)).balanceOfUnderlying(address(venusAdapter));
    vaultManagerBalance = usdc.balanceOf(address(vaultManager));
    assertTrue(venusAdapterBalance <= 101 ether && venusAdapterBalance > 99 ether, "venusAdapterBalance 1 error");
    assertEq(vaultManagerBalance, 0, "vaultManagerBalance 1 error");

    vm.stopPrank();
  }

  function test_setAdapter() public {
    vm.startPrank(admin);
    vaultManager.addAdapter(address(venusAdapter), 100);
    vm.stopPrank();

    (, bool active, uint256 point) = vaultManager.adapters(0);
    assertTrue(active, "0 adapter active error");
    assertEq(point, 100, "0 adapter point error");

    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(vaultManager.MANAGER()), 32)
      )
    );
    vaultManager.setAdapter(0, false, 0);
    vm.stopPrank();

    vm.startPrank(admin);
    vaultManager.setAdapter(0, false, 10);
    vm.stopPrank();

    (, active, point) = vaultManager.adapters(0);
    assertTrue(!active, "1 adapter active error");
    assertEq(point, 10, "1 adapter point error");
  }

  function test_rebalance() public {
    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(vaultManager.BOT()), 32)
      )
    );

    vaultManager.rebalance();
    vm.stopPrank();

    vm.startPrank(admin);
    vaultManager.grantRole(vaultManager.BOT(), admin);

    vm.expectRevert("no adapter");
    vaultManager.rebalance();

    vaultManager.addAdapter(address(venusAdapter), 100);
    vaultManager.rebalance();
    vm.stopPrank();
  }

  function test_emergencyWithdraw() public {
    usdc.mint(user1, 1000 ether);

    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(vaultManager.DEFAULT_ADMIN_ROLE()), 32)
      )
    );

    vaultManager.emergencyWithdraw(0);
    vm.stopPrank();

    vm.startPrank(admin);
    vaultManager.addAdapter(address(venusAdapter), 100);
    vm.stopPrank();

    vm.startPrank(user1);
    usdc.approve(address(vaultManager), MAX_UINT);

    vaultManager.deposit(100 ether);
    vm.stopPrank();

    vm.startPrank(admin);
    vaultManager.emergencyWithdraw(0);
    vm.stopPrank();

    uint256 usdcBalance = usdc.balanceOf(address(admin));
    assertTrue(usdcBalance <= 100 ether && usdcBalance >= 100 ether - 1e9, "admin USDC 0 error");
  }

  function test_initialize() public {
    address zero = address(0x0);
    VaultManager vaultManagerImpl = new VaultManager();

    vm.expectRevert("admin cannot be zero address");
    new ERC1967Proxy(
      address(vaultManagerImpl),
      abi.encodeWithSelector(vaultManagerImpl.initialize.selector, zero, admin, admin, address(usdc))
    );

    vm.expectRevert("manager cannot be zero address");
    new ERC1967Proxy(
      address(vaultManagerImpl),
      abi.encodeWithSelector(vaultManagerImpl.initialize.selector, admin, zero, admin, address(usdc))
    );

    vm.expectRevert("psm cannot be zero address");
    new ERC1967Proxy(
      address(vaultManagerImpl),
      abi.encodeWithSelector(vaultManagerImpl.initialize.selector, admin, admin, zero, address(usdc))
    );

    vm.expectRevert("token cannot be zero address");
    new ERC1967Proxy(
      address(vaultManagerImpl),
      abi.encodeWithSelector(vaultManagerImpl.initialize.selector, admin, admin, admin, address(0))
    );
  }

  function test_gas() public {
    usdc.mint(user1, 1000 ether);

    address adapter1 = createAdapter();
    address adapter2 = createAdapter();

    vm.startPrank(admin);
    vaultManager.addAdapter(adapter1, 100);
    vaultManager.addAdapter(adapter2, 100);
    vm.stopPrank();

    vm.startPrank(user1);
    usdc.approve(address(vaultManager), MAX_UINT);

    vaultManager.deposit(100 ether);

    vaultManager.withdraw(user1, 50 ether);
    vm.stopPrank();

    vm.startPrank(admin);
    uint256 startIdx = block.number % 2;
    vaultManager.setAdapter(startIdx, false, 0);
    vm.stopPrank();

    vm.startPrank(user1);
    vaultManager.withdraw(user1, 50 ether);
    vm.stopPrank();
  }

  function createAdapter() private returns (address) {
    vm.startPrank(admin);
    VenusAdapter venusAdapterImpl = new VenusAdapter();

    ERC1967Proxy venusAdapterProxy = new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        admin,
        admin,
        address(vaultManager),
        address(usdc),
        address(vUsdc),
        admin
      )
    );

    address adapter = address(venusAdapterProxy);

    vm.stopPrank();
    return adapter;
  }
}

contract MockERC20VM is ERC20 {
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}

contract MockVBep20VM is ERC20("Mock vToken", "mvToken"), IVBep20Delegate {
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
