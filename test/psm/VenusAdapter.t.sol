pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/VenusAdapter.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../contracts/interfaces/IVBep20Delegate.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract VenusAdapterTest is Test {
  VenusAdapter venusAdapter;
  MockERC20VA usdc;
  MockVBep20VA vUsdc;
  address admin = address(0x10);
  address user1 = address(0x004319Fd76912890F7920aEE99Df27EBA05ef48D);

  uint256 constant MAX_UINT = type(uint256).max;

  function setUp() public {
    vm.deal(admin, 100 ether);
    vm.deal(user1, 100 ether);

    usdc = new MockERC20VA("Mock USDC", "mUSDC");
    vUsdc = new MockVBep20VA(IERC20(address(usdc)));

    vm.startPrank(admin);
    VenusAdapter venusAdapterImpl = new VenusAdapter();

    ERC1967Proxy venusAdapterProxy = new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        admin,
        admin,
        user1,
        address(usdc),
        address(vUsdc),
        admin
      )
    );

    venusAdapter = VenusAdapter(address(venusAdapterProxy));

    vm.stopPrank();
  }

  function test_depositAndWithdraw() public {
    usdc.mint(user1, 200 ether);

    uint256 vUSDCBalance = IERC20(address(vUsdc)).balanceOf(address(venusAdapter));
    assertEq(vUSDCBalance, 0, "vUSDC 0 error");

    vm.startPrank(user1);
    usdc.approve(address(venusAdapter), 100 ether);
    venusAdapter.deposit(100 ether);
    vm.stopPrank();

    vUSDCBalance = IERC20(address(vUsdc)).balanceOf(address(venusAdapter));
    uint256 gemAmount = IVBep20Delegate(address(vUsdc)).balanceOfUnderlying(address(venusAdapter));
    assertTrue(vUSDCBalance > 0, "vUSDC 1 error");
    assertTrue(gemAmount > 99 ether && gemAmount <= 100 ether, "Staked USDC 1 error");

    vm.startPrank(user1);
    venusAdapter.withdraw(user1, 99 ether);
    vm.stopPrank();

    uint256 USDCBalance = usdc.balanceOf(user1);
    assertEq(USDCBalance, 199 ether, "user1 USDC 2 error");
  }

  function test_withdrawAll() public {
    usdc.mint(user1, 1000 ether);

    uint256 USDCBalance = usdc.balanceOf(user1);
    assertEq(USDCBalance, 1000 ether, "user1 USDC 0 error");

    vm.startPrank(user1);
    usdc.approve(address(venusAdapter), 100 ether);
    venusAdapter.deposit(100 ether);

    venusAdapter.withdrawAll();
    vm.stopPrank();

    USDCBalance = usdc.balanceOf(user1);
    assertTrue(USDCBalance <= 1000 ether && USDCBalance >= 999 ether, "user1 USDC 1 error");
  }

  function test_initialize() public {
    address zero = address(0x0);

    VenusAdapter venusAdapterImpl = new VenusAdapter();

    vm.expectRevert("admin cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        zero,
        admin,
        admin,
        address(usdc),
        address(vUsdc),
        admin
      )
    );

    vm.expectRevert("manager cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        admin,
        zero,
        admin,
        address(usdc),
        address(vUsdc),
        admin
      )
    );

    vm.expectRevert("vaultManager cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        admin,
        admin,
        zero,
        address(usdc),
        address(vUsdc),
        admin
      )
    );

    vm.expectRevert("token cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, admin, admin, admin, zero, address(vUsdc), admin)
    );

    vm.expectRevert("vToken cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, admin, admin, admin, address(usdc), zero, admin)
    );

    vm.expectRevert("feeReceiver cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        admin,
        admin,
        admin,
        address(usdc),
        address(vUsdc),
        zero
      )
    );
  }

  function test_harvest() public {
    usdc.mint(user1, 100 ether);
    vm.startPrank(user1);
    usdc.approve(address(venusAdapter), MAX_UINT);
    venusAdapter.deposit(100 ether);

    assertEq(usdc.balanceOf(user1), 0, "user1 0 USDC balance error");
    assertEq(usdc.balanceOf(admin), 0, "admin 0 USDC balance error");

    usdc.mint(address(vUsdc), 10 ether);
    vUsdc.setExchangeRate(1.1e18);

    venusAdapter.harvest();
    assertEq(usdc.balanceOf(user1), 0, "user1 1 USDC balance error");
    assertTrue(usdc.balanceOf(admin) > 0, "admin 1 USDC balance error");

    uint256 currentShares = IERC20(address(vUsdc)).balanceOf(address(venusAdapter));
    uint256 targetRate = 1.2e18;
    vUsdc.setExchangeRate(targetRate);
    uint256 currentUnderlying = usdc.balanceOf(address(vUsdc));
    uint256 targetUnderlying = Math.mulDiv(currentShares, targetRate, 1e18);
    if (targetUnderlying > currentUnderlying) {
      usdc.mint(address(vUsdc), targetUnderlying - currentUnderlying);
    }

    uint256 withdrawn = venusAdapter.withdrawAll();
    assertApproxEqAbs(withdrawn, 100 ether, 1, "withdrawn amount error");
    assertApproxEqAbs(usdc.balanceOf(user1), 100 ether, 1, "user1 2 USDC balance error");

    vm.stopPrank();
  }

  function test_setFeeReceiver() public {
    address feeReceiver = address(0x20);
    address zero = address(0x0);

    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        StringsUpgradeable.toHexString(user1),
        " is missing role ",
        StringsUpgradeable.toHexString(uint256(venusAdapter.MANAGER()), 32)
      )
    );
    venusAdapter.setFeeReceiver(feeReceiver);
    vm.stopPrank();

    vm.startPrank(admin);
    vm.expectRevert("feeReceiver cannot be zero address");
    venusAdapter.setFeeReceiver(zero);

    venusAdapter.setFeeReceiver(feeReceiver);
    vm.stopPrank();
    assertEq(venusAdapter.feeReceiver(), feeReceiver, "feeReceiver set error");
  }
}

contract MockERC20VA is ERC20 {
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}

contract MockVBep20VA is ERC20("Mock vToken", "mvToken"), IVBep20Delegate {
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
