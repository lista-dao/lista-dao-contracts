// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IResilientOracle } from "./interfaces/IResilientOracle.sol";

contract SlisBnbOracle is Initializable {

  // @dev resilient oracle address
  address constant public RESILIENT_ORACLE_ADDR = 0xf3afD82A4071f272F403dC176916141f44E6c750;
  // @dev slisBNB token address
  address constant public SLISBNB_TOKEN_ADDR = 0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B;

  /**
   * Get the latest price of slisBNB
   */
  function peek() public view returns (bytes32, bool) {
    uint256 price = IResilientOracle(RESILIENT_ORACLE_ADDR).peek(SLISBNB_TOKEN_ADDR);
    return (bytes32(uint(price) * 1e10), true);
  }
}
