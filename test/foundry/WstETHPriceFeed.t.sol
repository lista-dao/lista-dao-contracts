pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/oracle/priceFeeds/WstETHPriceFeed.sol";

contract WstETHPriceFeeTest is Test {
    WstETHPriceFeed priceFeed;
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address wstETH_ETH_PriceFeed = 0xE7e734789954e6CffD8C295CBD0916A0A5747D27;

    function setUp() public {
        vm.createSelectFork("bsc-main");

        priceFeed = new WstETHPriceFeed(resilientOracle, wstETH_ETH_PriceFeed);
    }

    function test_getPrice() public {
        (,int256 price,,,) = priceFeed.latestRoundData();
        console.log("wstETH price", price);
    }
}
