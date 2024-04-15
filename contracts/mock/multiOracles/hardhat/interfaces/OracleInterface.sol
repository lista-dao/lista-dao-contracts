// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

interface OracleInterfaceMock {
  function getPrice(address asset) external view returns (uint256);
}

interface PriceFeedInterfaceMock {

  function latestRoundData()
  external
  view
  returns (uint80, uint256, uint256, uint256, uint80);

}

interface BoundValidatorInterfaceMock {
  function validatePriceWithAnchorPrice(
    address asset,
    uint256 reporterPrice,
    uint256 anchorPrice
  ) external view returns (bool);
}
