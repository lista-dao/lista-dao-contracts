// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract AsUsdfOracle is Initializable {

  IResilientOracle public resilientOracle;
  address constant ASUSDF_TOKEN_ADDR = 0xb77380b3d7E384Aa05477A7eEAEd4db3420216f1;

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
