// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IResilientOracle.sol";

contract mBTCOracle is Initializable {
  IResilientOracle public constant resilientOracle = IResilientOracle(0xf3afD82A4071f272F403dC176916141f44E6c750);
  address public constant BTC_TOKEN = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c; // BTCB token address
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer {}

  /**
   * Returns the latest price
   */
  function peek() public view returns (bytes32, bool) {
    uint256 price = resilientOracle.peek(BTC_TOKEN);
    return (bytes32(uint(price) * 1e10), true);
  }
}
