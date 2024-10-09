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

        TransparentUpgradeableProxy venusAdapterProxy = new TransparentUpgradeableProxy(
            address(venusAdapterImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(
                venusAdapterImpl.initialize.selector,
                user1,
                venusPool,
                USDC,
                vUSDC,
                quotaAmount
            )
        );

        venusAdapter = VenusAdapter(address(venusAdapterProxy));

        vm.stopPrank();


    }

    function test_depositAndWithdraw() public {
        deal(USDC, user1, 200 ether);

        uint256 vUSDCBalance = IERC20(vUSDC).balanceOf(address(venusAdapter));
        console.log("vUSDC: ", vUSDCBalance);

        vm.startPrank(user1);
        IERC20(USDC).approve(address(venusAdapter), 100 ether);
        venusAdapter.deposit(100 ether);
        vm.stopPrank();

        vUSDCBalance = IERC20(vUSDC).balanceOf(address(venusAdapter));
        console.log("vUSDC: ", vUSDCBalance);

        uint256 gemAmount = venusAdapter.totalAvailableAmount();
        console.log("Staked USDC:: ", gemAmount);


        vm.startPrank(user1);
        venusAdapter.withdraw(user1, 99 ether);
        vm.stopPrank();

        uint256 USDCBalance = IERC20(USDC).balanceOf(user1);
        console.log("user1 USDC: ", USDCBalance);
        USDCBalance = IERC20(USDC).balanceOf(address(venusAdapter));
        console.log("adapter USDC: ", USDCBalance);
        vUSDCBalance = IERC20(vUSDC).balanceOf(address(venusAdapter));
        console.log("vUSDC: ", vUSDCBalance);

//        console.log("block1", block.number);
//        vm.roll(block.number + 10000);
//        console.log("block2", block.number);
//
//        IVBep20Delegate(venusPool).accrueInterest();
//        gemAmount = venusAdapter.totalAvailableAmount();
//        console.log("Staked USDC:: ", gemAmount);

    }
}