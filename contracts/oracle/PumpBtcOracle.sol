// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IResilientOracle.sol";

contract PumpBtcOracle is Initializable {
  // FIXME
  IResilientOracle public constant resilientOracle = IResilientOracle(0x79e9675cDe605Ef9965AbCE185C5FD08d0DE16B1);
  // FIXME
  address public constant BTC_TOKEN = 0x4BB2f2AA54c6663BFFD37b54eCd88eD81bC8B3ec;

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
    if (price <= 0) {
      return (0, false);
    }
    price = (uint(price) * 1e10 * 99) / 100; // 0.99 * btc price
    return (bytes32(price), true);
  }
}
