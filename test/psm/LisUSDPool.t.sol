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
    address vat = 0x33A34eAB3ee892D40420507B820347b1cA2201c4;

    address lisUSDAuth = 0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37;

    uint256 MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 MAX_DUTY = 1000000005781378656804590540;


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
                lisUSD,
                vat,
                MAX_DUTY
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
        deal(lisUSD, admin, 10000 ether);

        address[] memory pools = new address[](1);
        pools[0] = address(lisUSDPool);

        vm.startPrank(admin);
        lisUSDPool.setDuty(1000000005781378656804590540);
        IERC20(lisUSD).transfer(address(lisUSDPool), 100 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        IERC20(lisUSD).approve(address(lisUSDPool), MAX_UINT);

        lisUSDPool.deposit(100 ether);

        uint256 lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        uint256 poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
        console.log("user1 lisUSD 0: ", lisUSDBalance);
        console.log("pool lisUSD 0: ", poolBalance);

        skip(365 days);

        lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
        console.log("user1 lisUSD 1: ", lisUSDBalance);
        console.log("pool lisUSD 1: ", poolBalance);

        skip(365 days);

        uint256 lisUSDPoolBalance = lisUSDPool.balanceOf(user1);
        console.log("user1 lisUSDPool balance2: ", lisUSDPoolBalance);
        lisUSDPool.withdraw(pools, lisUSDPoolBalance);
        lisUSDBalance = IERC20(lisUSD).balanceOf(user1);
        poolBalance = IERC20(lisUSD).balanceOf(address(lisUSDPool));
        console.log("user1 lisUSD 2: ", lisUSDBalance);
        console.log("pool lisUSD 2: ", poolBalance);

        vm.stopPrank();

    }
}