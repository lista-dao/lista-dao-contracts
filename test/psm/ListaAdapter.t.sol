pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../contracts/psm/ListaAdapter.sol";

contract ListaAdapterTest is Test {
    ListaAdapter listaAdapter;
    address admin = address(0x1);
    address user1 = address(0x2);
    address venusPool = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
    address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    ProxyAdmin proxyAdmin = ProxyAdmin(0xBd8789025E91AF10487455B692419F82523D29Be);

    function setUp() public {
        vm.createSelectFork("bsc-main");

        vm.deal(admin, 100 ether);
        vm.deal(user1, 100 ether);

        vm.startPrank(admin);
        ListaAdapter listaAdpaterImpl = new ListaAdapter();

        TransparentUpgradeableProxy listaAdapterProxy = new TransparentUpgradeableProxy(
            address(listaAdpaterImpl),
            address(proxyAdmin),
            abi.encodeWithSelector(
                listaAdpaterImpl.initialize.selector,
                admin,
                admin,
                USDC,
                user1
            )
        );

        listaAdapter = ListaAdapter(address(listaAdapterProxy));

        vm.stopPrank();


    }

    function test_depositAndWithdraw() public {
        deal(USDC, user1, 200 ether);

        uint256 USDCBalance = IERC20(USDC).balanceOf(user1);
        assertEq(USDCBalance, 200 ether, "user1 USDC balance error");

        vm.startPrank(user1);
        IERC20(USDC).approve(address(listaAdapter), 100 ether);
        listaAdapter.deposit(100 ether);
        vm.stopPrank();

        uint256 gemAmount = listaAdapter.totalAvailableAmount();
        assertEq(gemAmount, 100 ether, "Staked USDC error");

        vm.startPrank(user1);
        listaAdapter.withdraw(user1, 100 ether);
        vm.stopPrank();

        USDCBalance = IERC20(USDC).balanceOf(user1);
        assertEq(USDCBalance, 200 ether, "user1 USDC balance error");
        USDCBalance = IERC20(USDC).balanceOf(address(listaAdapter));
        assertEq(USDCBalance, 0, "adapter USDC balance error");

        gemAmount = listaAdapter.totalAvailableAmount();
        assertEq(gemAmount, 0, "Staked USDC error");

    }

    function test_setOperator() public {
        vm.startPrank(admin);
        listaAdapter.grantRole(listaAdapter.MANAGER(), user1);
        vm.stopPrank();

        bool r = listaAdapter.hasRole(listaAdapter.MANAGER(), user1);
        assertEq(r, true, "operator error");

        vm.startPrank(admin);
        listaAdapter.revokeRole(listaAdapter.MANAGER(), user1);
        vm.stopPrank();

        r = listaAdapter.hasRole(listaAdapter.MANAGER(), user1);
        assertEq(r, false, "operator error");
    }

    function test_operatorDepositAndWithdraw() public {
        deal(USDC, user1, 200 ether);

        uint256 USDCBalance = IERC20(USDC).balanceOf(user1);
        assertEq(USDCBalance, 200 ether, "user1 USDC balance error");

        vm.startPrank(admin);
        listaAdapter.grantRole(listaAdapter.MANAGER(), user1);
        vm.stopPrank();

        vm.startPrank(user1);
        IERC20(USDC).approve(address(listaAdapter), 1000 ether);
        listaAdapter.deposit(100 ether);

        uint256 gemAmount = listaAdapter.totalAvailableAmount();
        assertEq(gemAmount, 100 ether, "Staked USDC error");

        listaAdapter.withdrawByOperator(10 ether);

        USDCBalance = IERC20(USDC).balanceOf(user1);
        assertEq(USDCBalance, 110 ether, "user1 USDC balance error");
        USDCBalance = IERC20(USDC).balanceOf(address(listaAdapter));
        assertEq(USDCBalance, 90 ether, "adapter USDC balance error");
        gemAmount = listaAdapter.totalAvailableAmount();
        assertEq(gemAmount, 90 ether, "Staked USDC error");

        listaAdapter.depositByOperator(110 ether);

        USDCBalance = IERC20(USDC).balanceOf(user1);
        assertEq(USDCBalance, 0, "user1 USDC balance error");
        USDCBalance = IERC20(USDC).balanceOf(address(listaAdapter));
        assertEq(USDCBalance, 200 ether, "adapter USDC balance error");
        gemAmount = listaAdapter.totalAvailableAmount();
        assertEq(gemAmount, 200 ether, "Staked USDC error");

        vm.stopPrank();
    }
}