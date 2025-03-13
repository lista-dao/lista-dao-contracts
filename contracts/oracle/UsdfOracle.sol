// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract UsdfOracle is Initializable {

  IResilientOracle public resilientOracle;
  address constant USDF_TOKEN_ADDR = 0x40326b7d4B52B750E98456388a24603E977eC56B;

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
    // get USDF price (8 decimals)
    uint256 price = resilientOracle.peek(USDF_TOKEN_ADDR);
    // returns in 18 decimals
    return (bytes32(uint(price) * 1e10), true);
  }
}
