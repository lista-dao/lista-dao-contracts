pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../contracts/oracle/priceFeeds/uniBTCPriceFeed.sol";
import "../../../contracts/oracle/interfaces/IResilientOracle.sol";
import "../../../contracts/oracle/interfaces/AggregatorV3Interface.sol";
import "../../../contracts/oracle/priceFeeds/yUSDPriceFeed.sol";


contract PriceFeedTest is Test {
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    function setUp() public {
        vm.createSelectFork("bsc-main");
    }

    function test_uniBTCPriceFeed() public {
        address uniBTC_BTC_PriceFeed = 0x921Fa3C67286385b22dE244e51E5925D98B03130;
        uniBTCPriceFeed feed = new uniBTCPriceFeed(resilientOracle, uniBTC_BTC_PriceFeed);
        (, int256 answer,,,) = feed.latestRoundData();

        uint256 btcPrice = IResilientOracle(resilientOracle).peek(feed.BTC_TOKEN_ADDR());
        (, int256 uniBTC_BTC_Price,,,) = AggregatorV3Interface(uniBTC_BTC_PriceFeed).latestRoundData();

        assertEq(int256(Math.mulDiv(uint256(uniBTC_BTC_Price), btcPrice, 1e18)), answer);
    }

    function test_yUSDPriceFeed() public {
        yUSDPriceFeed feed = new yUSDPriceFeed(resilientOracle);
        (, int256 answer,,,) = feed.latestRoundData();

        uint256 USDTPrice = IResilientOracle(resilientOracle).peek(feed.USDT_TOKEN_ADDR());
        uint256 yUSD_USDT_Price = feed.yUSD().convertToAssets(1e18);

        assertEq(int256(Math.mulDiv(yUSD_USDT_Price, USDTPrice, 1e18)), answer);
    }
}