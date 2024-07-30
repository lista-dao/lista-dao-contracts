// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ISnBnbStakeManager } from "../snbnb/interfaces/ISnBnbStakeManager.sol";
import { IResilientOracle } from "./interfaces/IResilientOracle.sol";

contract SlisBnbOracle is Initializable {

  AggregatorV3Interface internal priceFeed;
  // @dev Stake Manager Address
  address internal constant stakeManagerAddr = 0x1adB950d8bB3dA4bE104211D5AB038628e477fE6;
  // @dev resilient oracle address
  address constant public resilientOracleAddr = 0xf3afD82A4071f272F403dC176916141f44E6c750;
  // @dev *WBNB* token address
  address constant public TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  function initialize(address aggregatorAddress) external initializer {
    priceFeed = AggregatorV3Interface(aggregatorAddress);
  }

  /**
   * Returns the latest price
   */
  function peek() public view returns (bytes32, bool) {
    // get BNB price from resilient oracle, 8 decimals
    uint256 price = IResilientOracle(resilientOracleAddr).peek(TOKEN);
    if (price <= 0) {
      return (0, false);
    }
    return (bytes32(uint(price) * ISnBnbStakeManager(stakeManagerAddr).convertSnBnbToBnb(10**10)), true);
  }
}
