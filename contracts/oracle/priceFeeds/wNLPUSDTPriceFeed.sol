// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";
import "../interfaces/IWNLP.sol";

/**
  * @title wNLP-USDT Price Feed
  * @dev This contract get the price of USDT from the Resilient Oracle
  *      and the exchange rate of wNLP-USDT/USDT from the wNLP-USDT contract,
  *      and returns the price of wNLP-USDT in USD.
  */
contract wNLPUSDTPriceFeed {

    IResilientOracle public resilientOracle;
    // wNLP-USDT Token Address (non-upgradeable)
    IWNLP public wNLPUSDT = IWNLP(0xEA5FF211eF700DccC521a1e6501C9fe1B95D8EE7);
    address public constant USDT_TOKEN_ADDR = 0x55d398326f99059fF775485246999027B3197955;

    /**
      * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    */
    constructor(address _resilientOracle) {
        require(_resilientOracle != address(0), "Zero address provided");
        resilientOracle = IResilientOracle(_resilientOracle);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "wNLP-USDT/USD Price Feed";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function latestAnswer() external view returns (int256 answer) {
        // get price
        uint256 price = getPrice();
        // cast price to int256
        answer = int256(price);
    }

    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        // get price
        uint256 _answer = getPrice();
        // mock timestamp to latest block timestamp
        uint256 timestamp = block.timestamp;
        // mock roundId to timestamp
        roundId = uint80(timestamp);
        return (
            roundId,
            int256(_answer),
            timestamp,
            timestamp,
            roundId
        );
    }

    /**
      * @dev Get the price of wNLP-USDT/USDT from wNLP-USDT contract,
    *      and USDT/USD from resilient oracle,
    *      multiply them and divide by 1e8
    * @return price The price of wNLP-USDT/USD in 8 decimal places
    */
    function getPrice() private view returns (uint256 price) {
        uint256 DENOMINATOR = 1e18;
        // wNLP-USDT/USDT rate in 18 DPs
        uint256 wNLPUSDT_USDT_Rate = wNLPUSDT.getNlpByWnlp(DENOMINATOR);
        require(wNLPUSDT_USDT_Rate > 0, "wNLPUSDTPriceFeed/rate-not-valid");
        // wNLP-USDT/USD in 8 DPs
        uint256 usdtPrice = resilientOracle.peek(USDT_TOKEN_ADDR);
        // return wNLP-USDT/USD price in 8 DPs
        return FullMath.mulDiv(usdtPrice, wNLPUSDT_USDT_Rate, DENOMINATOR);
    }

}
