// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ISnBnbStakeManager } from "../snbnb/interfaces/ISnBnbStakeManager.sol";
import { IResilientOracle } from "../oracle/interfaces/IResilientOracle.sol";

contract SlisBnbOracleMock is Initializable {

  AggregatorV3Interface internal priceFeed;
  // @dev Stake Manager Address
  address internal constant stakeManagerAddr = 0xc695F964011a5a1024931E2AF0116afBaC41B31B;
  // @dev New price feed address
  address internal constant bnbPriceFeedAddr = 0xC09568Ca692bef72D33fCBDEBa790867aeFf3351;
  // @dev resilient oracle address
  address internal constant resilientOracleAddr = 0x9CCf790F691925fa61b8cB777Cb35a64F5555e53;
  // @dev *WBNB* token address
  address constant public TOKEN = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;

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
