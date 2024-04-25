// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface OracleInterface {
  function peek(address asset) external view returns (uint256);
}

interface IAPI3Proxy {
  function read()
  external
  view
  returns (int224 value, uint32 timestamp);
}

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function latestAnswer() external view returns (int256);

  function getRoundData(uint80 _roundId)
  external
  view
  returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  );

  function latestRoundData()
  external
  view
  returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  );
}

interface BoundValidatorInterface {
  function validatePriceWithAnchorPrice(
    address asset,
    uint256 reporterPrice,
    uint256 anchorPrice
  ) external view returns (bool);
}

