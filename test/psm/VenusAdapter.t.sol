pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/VenusAdapter.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract VenusAdapterTest is Test {
  VenusAdapter venusAdapter;
  address admin = address(0x10);
  address user1 = address(0x004319Fd76912890F7920aEE99Df27EBA05ef48D);
  address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
  address vUSDC = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
  ProxyAdmin proxyAdmin = ProxyAdmin(0xBd8789025E91AF10487455B692419F82523D29Be);
  uint256 quotaAmount = 1e18;

  function setUp() public {
    vm.createSelectFork("bsc-main");

    vm.deal(admin, 100 ether);
    vm.deal(user1, 100 ether);

    vm.startPrank(admin);
    VenusAdapter venusAdapterImpl = new VenusAdapter();

    ERC1967Proxy venusAdapterProxy = new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, admin, admin, user1, USDC, vUSDC, admin)
    );

    venusAdapter = VenusAdapter(address(venusAdapterProxy));

    vm.stopPrank();
  }

  function test_depositAndWithdraw() public {
    deal(USDC, user1, 200 ether);

    uint256 vUSDCBalance = IERC20(vUSDC).balanceOf(address(venusAdapter));
    assertEq(vUSDCBalance, 0, "vUSDC 0 error");

    vm.startPrank(user1);
    IERC20(USDC).approve(address(venusAdapter), 100 ether);
    venusAdapter.deposit(100 ether);
    vm.stopPrank();

    vUSDCBalance = IERC20(vUSDC).balanceOf(address(venusAdapter));
    uint256 gemAmount = IVBep20Delegate(vUSDC).balanceOfUnderlying(address(venusAdapter));
    assertTrue(vUSDCBalance > 0, "vUSDC 1 error");
    assertTrue(gemAmount > 99 ether && gemAmount <= 100 ether, "Staked USDC 1 error");

    vm.startPrank(user1);
    venusAdapter.withdraw(user1, 99 ether);
    vm.stopPrank();

    uint256 USDCBalance = IERC20(USDC).balanceOf(user1);
    assertEq(USDCBalance, 199 ether, "user1 USDC 2 error");

    //        console.log("block1", block.number);
    //        vm.roll(block.number + 10000);
    //        console.log("block2", block.number);
    //
    //        IVBep20Delegate(venusPool).accrueInterest();
    //        gemAmount = venusAdapter.totalAvailableAmount();
    //        console.log("Staked USDC:: ", gemAmount);
  }

  function test_withdrawAll() public {
    deal(USDC, user1, 1000 ether);

    uint256 USDCBalance = IERC20(USDC).balanceOf(user1);
    assertEq(USDCBalance, 1000 ether, "user1 USDC 0 error");

    vm.startPrank(user1);
    IERC20(USDC).approve(address(venusAdapter), 100 ether);
    venusAdapter.deposit(100 ether);

    venusAdapter.withdrawAll();
    vm.stopPrank();

    USDCBalance = IERC20(USDC).balanceOf(user1);
    assertTrue(USDCBalance <= 1000 ether && USDCBalance >= 999 ether, "user1 USDC 1 error");
  }

  function test_initialize() public {
    address zero = address(0x0);

    VenusAdapter venusAdapterImpl = new VenusAdapter();

    vm.expectRevert("admin cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, zero, admin, admin, USDC, vUSDC, admin)
    );

    vm.expectRevert("manager cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, admin, zero, admin, USDC, vUSDC, admin)
    );

    vm.expectRevert("vaultManager cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, admin, admin, zero, USDC, vUSDC, admin)
    );

    vm.expectRevert("token cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, admin, admin, admin, zero, vUSDC, admin)
    );

    vm.expectRevert("vToken cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, admin, admin, admin, USDC, zero, admin)
    );

    vm.expectRevert("feeReceiver cannot be zero address");
    new ERC1967Proxy(
      address(venusAdapterImpl),
      abi.encodeWithSelector(venusAdapterImpl.initialize.selector, admin, admin, admin, USDC, vUSDC, zero)
    );
  }

  function test_harvest() public {
    deal(USDC, user1, 100 ether);
    vm.startPrank(user1);
    IERC20(USDC).approve(address(venusAdapter), UINT256_MAX);
    venusAdapter.deposit(100 ether);

    assertEq(IERC20(USDC).balanceOf(user1), 0, "user1 0 USDC balance error");
    assertEq(IERC20(USDC).balanceOf(admin), 0, "admin 0 USDC balance error");

    vm.roll(block.number + 10000);
    venusAdapter.harvest();
    assertEq(IERC20(USDC).balanceOf(user1), 0, "user1 1 USDC balance error");
    assertTrue(IERC20(USDC).balanceOf(admin) > 0, "admin 1 USDC balance error");

    vm.roll(block.number + 10000);
    venusAdapter.withdrawAll();
    assertTrue(IERC20(USDC).balanceOf(user1) > 100 ether, "user1 2 USDC balance error");

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
