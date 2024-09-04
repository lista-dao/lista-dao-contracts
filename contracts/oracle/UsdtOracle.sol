// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract UsdtOracle is Initializable {

  IResilientOracle public resilientOracle;
  address constant USDT_TOKEN_ADDR = 0x55d398326f99059fF775485246999027B3197955;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _resilientOracle) external initializer {
    resilientOracle = IResilientOracle(_resilientOracle);
  }

  /**
    * Returns the latest price
    */
  function peek() public view returns (bytes32, bool) {
    // get USDT price (8 decimals)
    uint256 price = resilientOracle.peek(USDT_TOKEN_ADDR);
    // returns in 18 decimals
    return (bytes32(uint(price) * 1e10), true);
  }
}
