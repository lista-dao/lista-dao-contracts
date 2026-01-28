pragma solidity ^0.8.10;

import "../../../contracts/oracle/interfaces/AggregatorV3Interface.sol";

import "../../../contracts/oracle/interfaces/IResilientOracle.sol";

import "../../../contracts/oracle/priceFeeds/USDXLiquidationPriceFeed.sol";
import "../../../contracts/oracle/priceFeeds/mXRPPriceFeed.sol";
import "../../../contracts/oracle/priceFeeds/sUSD1PriceFeed.sol";
import "../../../contracts/oracle/priceFeeds/sUSDXLiquidationPriceFeed.sol";
import "../../../contracts/oracle/priceFeeds/uniBTCPriceFeed.sol";
import "../../../contracts/oracle/priceFeeds/wNLPUSDTPriceFeed.sol";
import "../../../contracts/oracle/priceFeeds/wsrUSDPriceFeed.sol";
import "../../../contracts/oracle/priceFeeds/wstUSRPriceFeed.sol";
import "../../../contracts/oracle/priceFeeds/yUSDPriceFeed.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/Test.sol";


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

    function test_wstUSRPriceFeed() public {
        address wstUSR_stUSR_PriceFeed = 0xA40a0dC23D3A821fF5Ea9E23080B74DAC031158d;
        wstUSRPriceFeed feed = new wstUSRPriceFeed(resilientOracle, wstUSR_stUSR_PriceFeed);
        (, int256 answer,,,) = feed.latestRoundData();

        (, int256 wstUSR_stUSR_Price,,,) = AggregatorV3Interface(wstUSR_stUSR_PriceFeed).latestRoundData();

        assertEq(wstUSR_stUSR_Price / 1e10, answer);
    }

    function test_mXRPPriceFeed() public {
        address mXRP_XRP_PriceFeed = 0x3BdE0b7B59769Ec00c44C77090D88feB4516E731;
        mXRPPriceFeed feed = new mXRPPriceFeed(resilientOracle, mXRP_XRP_PriceFeed);
        (, int256 answer,,,) = feed.latestRoundData();

        uint256 xrpPrice = IResilientOracle(resilientOracle).peek(feed.XRP_TOKEN_ADDR());
        (, int256 mXRP_XRP_Price,,,) = AggregatorV3Interface(mXRP_XRP_PriceFeed).latestRoundData();

        assertEq(int256(Math.mulDiv(uint256(mXRP_XRP_Price), xrpPrice, 1e8)), answer);
    }

    function test_wsrUSDPriceFeed() public {
        address wsrUSD_srUSD_PriceFeed = 0x19995C3f82Ea476ae6c635BBbcb81c43030089eb;
        wsrUSDPriceFeed feed = new wsrUSDPriceFeed(resilientOracle, wsrUSD_srUSD_PriceFeed);
        (, int256 answer,,,) = feed.latestRoundData();

        (, int256 wsrUSD_srUSD_Price,,,) = AggregatorV3Interface(wsrUSD_srUSD_PriceFeed).latestRoundData();
        uint256 usdtPrice = IResilientOracle(resilientOracle).peek(feed.USDT_TOKEN_ADDR());

        assertEq(FullMath.mulDiv(uint256(wsrUSD_srUSD_Price), usdtPrice, 1e18), uint256(answer));
    }

    function test_sUSD1PriceFeed() public {
        address sUSD1_USD1_PriceFeed = 0x08CA3ac4dE41F2791e8A247859d637a8977473D7;
        sUSD1PriceFeed feed = new sUSD1PriceFeed(resilientOracle, sUSD1_USD1_PriceFeed);
        (, int256 answer,,,) = feed.latestRoundData();

        (, int256 sUSD1_USD1_Price,,,) = AggregatorV3Interface(sUSD1_USD1_PriceFeed).latestRoundData();
        uint256 usd1Price = IResilientOracle(resilientOracle).peek(feed.USD1_TOKEN_ADDR());

        assertEq(int256(Math.mulDiv(uint256(sUSD1_USD1_Price), usd1Price, 1e18)), answer);
    }

    function test_sUSDXPriceFeed() public {
        uint256 sUSDX_USDX_Price = 0.932 ether;
        sUSDXLiquidationPriceFeed feed = new sUSDXLiquidationPriceFeed(resilientOracle, sUSDX_USDX_Price);
        (, int256 answer,,,) = feed.latestRoundData();

        uint256 usdxPrice = IResilientOracle(resilientOracle).peek(feed.USDX_TOKEN_ADDR());

        assertEq(int256(Math.mulDiv(usdxPrice, sUSDX_USDX_Price, 1e18)), answer);

        vm.startPrank(0x8d388136d578dCD791D081c6042284CED6d9B0c6);
        sUSDX_USDX_Price = 0.94 ether;
        feed.setExchangeRate(sUSDX_USDX_Price);
        vm.stopPrank();

        (, answer,,,) = feed.latestRoundData();
        usdxPrice = IResilientOracle(resilientOracle).peek(feed.USDX_TOKEN_ADDR());

        assertEq(int256(Math.mulDiv(usdxPrice, sUSDX_USDX_Price, 1e18)), answer);
    }

    function test_USDXPriceFeed() public {
        uint256 USDX_USDX_Price = 8 * 1e7;
        USDXLiquidationPriceFeed feed = new USDXLiquidationPriceFeed(USDX_USDX_Price);
        (, int256 answer,,,) = feed.latestRoundData();

        assertEq(int256(USDX_USDX_Price), answer);

        vm.startPrank(0x8d388136d578dCD791D081c6042284CED6d9B0c6);
        USDX_USDX_Price = 7 * 1e7;
        feed.setPrice(USDX_USDX_Price);
        vm.stopPrank();

        (, answer,,,) = feed.latestRoundData();

        assertEq(int256(USDX_USDX_Price), answer);
    }

    function test_wNLPUSDTPriceFeed() public {
        IWNLP wNLP = IWNLP(0xEA5FF211eF700DccC521a1e6501C9fe1B95D8EE7);
        wNLPUSDTPriceFeed feed = new wNLPUSDTPriceFeed(resilientOracle);
        (, int256 answer,,,) = feed.latestRoundData();

        uint256 usdtPrice = IResilientOracle(resilientOracle).peek(feed.USDT_TOKEN_ADDR());
        uint256 wNLP_USDT_Rate = wNLP.getNlpByWnlp(1e18);

        assertEq(int256(Math.mulDiv(usdtPrice, wNLP_USDT_Rate, 1e18)), answer);
    }
}