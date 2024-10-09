pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/LisUSDPool.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/LisUSD.sol";
import "../../contracts/psm/EarnPool.sol";

contract LisUSDPoolTest is Test {
    LisUSDPool lisUSDPool;
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


        vm.stopPrank();

        vm.startPrank(lisUSDAuth);
        LisUSD(lisUSD).rely(address(lisUSDPool));
        vm.stopPrank();
    }

    function test_depositAndWithdraw() public {
        deal(lisUSD, user1, 100 ether + 1);

        vm.startPrank(admin);
        lisUSDPool.setDuty(1000000005781378656804590540);
        vm.stopPrank();

        vm.startPrank(user1);
        IERC20(lisUSD).approve(address(lisUSDPool), MAX_UINT);

        lisUSDPool.deposit(100 ether);

        uint256 lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        uint256 poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
        console.log("user1 lisUSD 0: ", lisUSDBalance);
        console.log("pool lisUSD 0: ", poolBalance);

        skip(365 days);

//        lisUSDPool.deposit(1);

        lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
        console.log("user1 lisUSD 1: ", lisUSDBalance);
        console.log("pool lisUSD 0: ", poolBalance);

        skip(365 days);

        lisUSDPool.withdrawAll();
        lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
        console.log("user1 lisUSD 1: ", lisUSDBalance);
        console.log("pool lisUSD 0: ", poolBalance);

        vm.stopPrank();

    }
}