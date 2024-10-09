pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/LisUSDPoolSet.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/LisUSD.sol";
import "../../contracts/hMath.sol";

contract PSMTest is Test {
    PSM psm;
    VaultManager vaultManager;
    address admin = address(0x1);
    address user1 = address(0x2);
    ProxyAdmin proxyAdmin = ProxyAdmin(0xBd8789025E91AF10487455B692419F82523D29Be);
    address lisUSD = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
    address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    address lisUSDAuth = 0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37;

    uint256 MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    function setUp() public {
        vm.createSelectFork("bsc-main");

        vm.deal(admin, 100 ether);
        vm.deal(user1, 100 ether);

        vm.startPrank(admin);
        PSM psmImpl = new PSM();

        TransparentUpgradeableProxy psmProxy = new TransparentUpgradeableProxy(
            address(psmImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(
                psmImpl.initialize.selector,
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

        TransparentUpgradeableProxy vaultManagerProxy = new TransparentUpgradeableProxy(
            address(vaultManagerImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(
                vaultManagerImpl.initialize.selector,
                admin,
                admin,
                address(psm),
                USDC
            )
        );

        vaultManager = VaultManager(address(vaultManagerProxy));

        psm.setVaultManager(address(vaultManager));

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
}