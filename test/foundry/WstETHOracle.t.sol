pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../contracts/oracle/priceFeeds/WstETHPriceFeed.sol";
import "../../contracts/oracle/wstETHOracle.sol";

contract WstETHOracleTest is Test {
    WstETHPriceFeed priceFeed;
    WstETHOracle oracle;
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address wstETH_ETH_PriceFeed = 0xE7e734789954e6CffD8C295CBD0916A0A5747D27;

    function setUp() public {
        vm.createSelectFork("bsc-main");

        priceFeed = new WstETHPriceFeed(resilientOracle, wstETH_ETH_PriceFeed);
        WstETHOracle oracleImpl = new WstETHOracle(address(priceFeed));

        ProxyAdmin proxyAdmin = new ProxyAdmin();

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(
                address(oracleImpl),
                address(proxyAdmin),
                abi.encodeWithSelector(oracleImpl.initialize.selector, resilientOracle)
            );

        oracle = WstETHOracle(address(proxy));

    }

    function test_getPrice() public {
        (bytes32 price,) = oracle.peek();
        console.log("wstETH price", uint256(price));
    }
}
