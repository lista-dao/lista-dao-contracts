// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ISnBnbStakeManager } from "../snbnb/interfaces/ISnBnbStakeManager.sol";

contract SlisBnbOracle is Initializable {

  AggregatorV3Interface internal priceFeed;
  // @dev Stake Manager Address
  address internal constant stakeManagerAddr = 0x1adB950d8bB3dA4bE104211D5AB038628e477fE6;
  // @dev New price feed address
  address internal constant bnbPriceFeedAddr = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

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

    require(block.timestamp - timeStamp < 300, "BnbOracle/timestamp-too-old");

    if (price < 0) {
      return (0, false);
    }
    return (bytes32(uint(price) * ISnBnbStakeManager(stakeManagerAddr).convertSnBnbToBnb(10**10)), true);
  }
}
