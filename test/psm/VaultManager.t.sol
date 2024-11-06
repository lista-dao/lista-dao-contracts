pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/LisUSDPoolSet.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/psm/VenusAdapter.sol";
import "../../contracts/LisUSD.sol";
import "../../contracts/hMath.sol";

contract VaultManagerTest is Test {
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

        VaultManager vaultManagerImpl = new VaultManager();

        TransparentUpgradeableProxy vaultManagerProxy = new TransparentUpgradeableProxy(
            address(vaultManagerImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(
                vaultManagerImpl.initialize.selector,
                admin,
                admin,
                address(user1),
                USDC
            )
        );

        vaultManager = VaultManager(address(vaultManagerProxy));

        VenusAdapter venusAdapterImpl = new VenusAdapter();

        TransparentUpgradeableProxy venusAdapterProxy = new TransparentUpgradeableProxy(
            address(venusAdapterImpl),
            address(proxyAdmin),
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

        vm.stopPrank();
    }

    function test_depositAndWithdraw() public {
        deal(USDC, user1, 1000 ether);

        vm.startPrank(admin);
        vaultManager.addAdapter(address(venusAdapter), 100);
        vm.stopPrank();

        vm.startPrank(user1);
        IERC20(USDC).approve(address(vaultManager), MAX_UINT);

        vaultManager.deposit(100 ether);

        uint256 usdcBalance = IERC20(USDC).balanceOf(user1);
        assertEq(usdcBalance, 900 ether, "user1 USDC 0 error");

        vaultManager.withdraw(user1, 99 ether);
        usdcBalance = IERC20(USDC).balanceOf(user1);
        assertEq(usdcBalance, 999 ether, "user1 USDC 1 error");
        vm.stopPrank();


    }

    function test_addAdapter() public {
        deal(USDC, user1, 1000 ether);

        vm.startPrank(admin);
        vaultManager.addAdapter(address(venusAdapter), 1000);
        vm.stopPrank();

        vm.startPrank(user1);
        IERC20(USDC).approve(address(vaultManager), MAX_UINT);

        vaultManager.deposit(1000 ether);

        uint256 venusAdapterBalance = venusAdapter.totalAvailableAmount();
        uint256 vaultManagerBalance = IERC20(USDC).balanceOf(address(vaultManager));
        assertTrue(venusAdapterBalance <= 1000 ether && venusAdapterBalance > 999 ether, "venusAdapterBalance 0 error");
        assertEq(vaultManagerBalance, 0, "vaultManagerBalance 0 error");

        vaultManager.withdraw(user1, 900 ether);
        venusAdapterBalance = venusAdapter.totalAvailableAmount();
        vaultManagerBalance = IERC20(USDC).balanceOf(address(vaultManager));
        assertTrue(venusAdapterBalance <= 100 ether && venusAdapterBalance > 98 ether, "venusAdapterBalance 1 error");
        assertEq(vaultManagerBalance, 0, "vaultManagerBalance 1 error");

        vm.stopPrank();
    }
}