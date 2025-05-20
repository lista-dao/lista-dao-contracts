pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/oracle/priceFeeds/WBETHPriceFeed.sol";

contract WBETHPriceFeeTest is Test {
    WBETHPriceFeed priceFeed;
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;

    function setUp() public {
        vm.createSelectFork("bsc-main");

        priceFeed = new WBETHPriceFeed(resilientOracle);
    }

    function test_getPrice() public {
        (,int256 price,,,) = priceFeed.latestRoundData();
        console.log("wBETH price", price);
    }
}
