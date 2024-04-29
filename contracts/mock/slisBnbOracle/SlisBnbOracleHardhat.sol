// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ISnBnbStakeManager } from "../../snbnb/interfaces/ISnBnbStakeManager.sol";

contract SlisBnbOracleHardhat is Initializable {

  AggregatorV3Interface internal priceFeed;
  // @dev Stake Manager Address
  address internal stakeManagerAddr;
  // @dev New price feed address
  address internal bnbPriceFeedAddr;

  constructor(address feedAdapterAddress, address _stakeManagerAddr) {
    bnbPriceFeedAddr = feedAdapterAddress;
    stakeManagerAddr = _stakeManagerAddr;
  }

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
    ) = AggregatorV3Interface(bnbPriceFeedAddr).latestRoundData();
    console.logString("[Contract log] Price: ");
    console.logInt(price);
    console.logString("[Contract log] Timestamp: ");
    console.logUint(timeStamp);

    uint256 conversionRate = ISnBnbStakeManager(stakeManagerAddr).convertBnbToSnBnb(10**10);
    console.logString("[Contract log] ConversionRate: ");
    console.logUint(conversionRate);

    require(block.timestamp - timeStamp < 300, "BnbOracle/timestamp-too-old");

    if (price < 0) {
      return (0, false);
    }
    return (bytes32(uint(price) * ISnBnbStakeManager(stakeManagerAddr).convertBnbToSnBnb(10**10)), true);
  }
}
