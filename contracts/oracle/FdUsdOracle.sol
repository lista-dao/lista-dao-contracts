// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract FdUsdOracle is Initializable {

  IResilientOracle public resilientOracle;
  address constant FDUSD_TOKEN_ADDR = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;

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
    // get FDUSD price (8 decimals)
    uint256 price = resilientOracle.peek(FDUSD_TOKEN_ADDR);
    // calculate wstETH/USD (18 decimals)
    return (bytes32(uint(price) * 1e12), true);
  }
}
