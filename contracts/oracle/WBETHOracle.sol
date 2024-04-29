// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract WBETHOracle is Initializable {

  AggregatorV3Interface internal priceFeed;

  function initialize(address aggregatorAddress) external initializer {
    priceFeed = AggregatorV3Interface(aggregatorAddress);
  }

  /**
   * Returns the latest price
   */
  function peek() public view returns (bytes32, bool) {
    (
    /*uint80 roundID*/,
      int price,
    /*uint startedAt*/,
      uint timeStamp,
    /*uint80 answeredInRound*/
    ) = priceFeed.latestRoundData();

    require(block.timestamp - timeStamp < 960, "Oracle/timestamp-too-old");

    if (price < 0) {
      return (0, false);
    }
    return (bytes32(uint(price) * (10**10)), true);
  }
}
