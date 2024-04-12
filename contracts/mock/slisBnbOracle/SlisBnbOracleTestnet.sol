// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ISnBnbStakeManager } from "../../snbnb/interfaces/ISnBnbStakeManager.sol";

contract SlisBnbOracleTestnet is Initializable {

  AggregatorV3Interface internal priceFeed;
  // @dev Stake Manager Address
  address internal constant stakeManagerAddr = 0x24B27246783DF12Fcf035Ea25c6d38e1a4146d93;
  // @dev New price feed address
  address internal constant bnbPriceFeedAddr = 0xC09568Ca692bef72D33fCBDEBa790867aeFf3351;

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
