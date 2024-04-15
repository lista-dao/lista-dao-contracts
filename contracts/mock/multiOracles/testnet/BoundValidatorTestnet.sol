// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import "./interfaces/IBoundValidator.sol";

/**
 * @title BoundValidator
 * @author Venus
 * @notice The BoundValidator contract is used to validate prices fetched from two different sources.
 * Each asset has an upper and lower bound ratio set in the config. In order for a price to be valid
 * it must fall within this range of the validator price.
 */
contract BoundValidatorTestnet is BoundValidatorInterfaceTestnet {

  /**
   * @notice Test reported asset price against anchor price
     * @param asset asset address
     * @param reportedPrice The price to be tested
     * @custom:error Missing error thrown if asset config is not set
     * @custom:error Price error thrown if anchor price is not valid
     */
  function validatePriceWithAnchorPrice(
    address asset,
    int256 reportedPrice,
    int256 anchorPrice
  ) public view virtual override returns (bool) {
    return reportedPrice > 0 && anchorPrice > 0;
  }

}
