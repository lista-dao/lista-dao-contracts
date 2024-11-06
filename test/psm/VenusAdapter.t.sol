pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/VenusAdapter.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract VenusAdapterTest is Test {
  VenusAdapter venusAdapter;
  address admin = address(0x1);
  address user1 = address(0x2);
  address venusPool = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
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
      abi.encodeWithSelector(
        venusAdapterImpl.initialize.selector,
        admin,
        admin,
        user1,
        venusPool,
        USDC,
        vUSDC,
        quotaAmount,
        admin
      )
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
    uint256 gemAmount = venusAdapter.totalAvailableAmount();
    assertTrue(vUSDCBalance > 0, "vUSDC 1 error");
    assertTrue(gemAmount > 99 ether && gemAmount <= 100 ether, "Staked USDC 1 error");

    vm.startPrank(user1);
    venusAdapter.withdraw(user1, 99 ether);
    vm.stopPrank();

    uint256 USDCBalance = IERC20(USDC).balanceOf(user1);
    assertEq(USDCBalance, 199 ether, "user1 USDC 2 error");
    USDCBalance = IERC20(USDC).balanceOf(address(venusAdapter));
    assertTrue(USDCBalance > 0 && USDCBalance <= 1 ether, "adapter USDC 2 error");
    vUSDCBalance = IERC20(vUSDC).balanceOf(address(venusAdapter));
    assertTrue(vUSDCBalance == 0 || vUSDCBalance == 1, "vUSDC 2 error");

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
}
