// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface OracleInterface {
  function getPrice(address asset) external view returns (uint256);
}

interface BoundValidatorInterface {
  function validatePriceWithAnchorPrice(
    address asset,
    uint256 reporterPrice,
    uint256 anchorPrice
  ) external view returns (bool);
}
