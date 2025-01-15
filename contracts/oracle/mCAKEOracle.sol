// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IResilientOracle.sol";

contract mCAKEOracle is Initializable {
  IResilientOracle public constant resilientOracle = IResilientOracle(0xf3afD82A4071f272F403dC176916141f44E6c750);
  address public constant CAKE_TOKEN = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82; // cake token address

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer {}

  /**
   * Returns the latest price
   */
  function peek() public view returns (bytes32, bool) {
    uint256 price = resilientOracle.peek(CAKE_TOKEN);
    return (bytes32(uint(price) * 1e10), true);
  }
}
