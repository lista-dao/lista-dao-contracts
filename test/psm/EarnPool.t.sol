pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/LisUSDPool.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/LisUSD.sol";
import "../../contracts/psm/EarnPool.sol";

contract EarnPoolTest is Test {
    PSM psm;
    VaultManager vaultManager;
    LisUSDPool lisUSDPool;
    EarnPool earnPool;
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
                USDC,
                admin,
                lisUSD,
                0,
                0,
                1e18 * 1e7,
                1e18*1e7,
                1e18*1e4,
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
                address(psm),
                USDC
            )
        );

        vaultManager = VaultManager(address(vaultManagerProxy));

        psm.setVaultManager(address(vaultManager));

        LisUSDPool lisUSDPoolImpl = new LisUSDPool();
        TransparentUpgradeableProxy lisUSDPoolProxy = new TransparentUpgradeableProxy(
            address(lisUSDPoolImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(
                lisUSDPoolImpl.initialize.selector,
                lisUSD
            )
        );

        lisUSDPool = LisUSDPool(address(lisUSDPoolProxy));

        EarnPool earnPoolImpl = new EarnPool();
        TransparentUpgradeableProxy earnPoolProxy = new TransparentUpgradeableProxy(
            address(earnPoolImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(
                earnPoolImpl.initialize.selector,
                "USDC Earn pool",
                "USDCep",
                address(psm),
                address(lisUSDPool),
                USDC,
                lisUSD,
                address(lisUSDPool)
            )
        );
        earnPool = EarnPool(address(earnPoolProxy));

        vm.stopPrank();

        vm.startPrank(lisUSDAuth);
        LisUSD(lisUSD).rely(address(psm));
        LisUSD(lisUSD).rely(address(lisUSDPool));
        vm.stopPrank();
    }

    function test_depositAndWithdraw() public {
        deal(USDC, user1, 1000 ether);

        vm.startPrank(user1);
        IERC20(USDC).approve(address(earnPool), MAX_UINT);

        earnPool.deposit(100 ether);

        uint256 usdcBalance = IERC20(USDC).balanceOf(user1);
        uint256 lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        console.log("user1 USDC 0: ", usdcBalance);
        console.log("user1 lisUSD 0: ", lisUSDBalance);

        earnPool.fetchRewards();

        console.log("lisUSDPool lisUSD balance 1: ", IERC20(lisUSD).balanceOf(address(lisUSDPool)));

        skip(1 days);

        earnPool.withdraw(100 ether);

        usdcBalance = IERC20(USDC).balanceOf(user1);
        lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        console.log("user1 USDC 1: ", usdcBalance);
        console.log("user1 lisUSD 1: ", lisUSDBalance);

        uint256 rewards = earnPool.rewards(user1);
        console.log("rewards 1: ", rewards);
        earnPool.withdraw(rewards);
        usdcBalance = IERC20(USDC).balanceOf(user1);
        lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        console.log("user1 USDC 2: ", usdcBalance);
        console.log("user1 lisUSD 2: ", lisUSDBalance);

        rewards = earnPool.rewards(user1);
        console.log("rewards 2: ", rewards);

        vm.stopPrank();

    }
}