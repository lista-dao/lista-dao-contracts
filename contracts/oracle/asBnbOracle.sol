// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IResilientOracle } from "./interfaces/IResilientOracle.sol";

contract AsBnbOracle is AccessControlUpgradeable, UUPSUpgradeable {

  // @dev resilient oracle address
  address constant public RESILIENT_ORACLE_ADDR = 0xf3afD82A4071f272F403dC176916141f44E6c750;
  // @dev asBNB token address
  address constant public AsBNB_TOKEN_ADDR = 0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev initialize the contract
   * @param _admin admin address
   */
  function initialize(address _admin) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  /**
   * @dev get the latest price of asBNB in USD
   */
  function peek() public view returns (bytes32, bool) {
    uint256 price = IResilientOracle(RESILIENT_ORACLE_ADDR).peek(AsBNB_TOKEN_ADDR);
    // price 8 DPs + conversion rate 10 DPs = 18 DPs
    return (bytes32(uint(price) * 10**10), true);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
