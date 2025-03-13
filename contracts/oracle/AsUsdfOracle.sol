// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract AsUsdfOracle is Initializable {

  IResilientOracle public resilientOracle;
  address constant ASUSDF_TOKEN_ADDR = 0x917AF46B3C3c6e1Bb7286B9F59637Fb7C65851Fb;

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
    // get asUSDF price (8 decimals)
    uint256 price = resilientOracle.peek(ASUSDF_TOKEN_ADDR);
    // returns in 18 decimals
    return (bytes32(uint(price) * 1e10), true);
  }
}
