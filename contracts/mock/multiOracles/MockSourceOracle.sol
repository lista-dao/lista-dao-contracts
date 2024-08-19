// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockSourceOracle is IMockSourceOracle, Ownable {

  int256 public price;
  uint256 public updateTimestamp;

  function setPrice(int256 _price) external onlyOwner {
    price = _price;
  }

  function setUpdateTimestamp(uint256 _updateTimestamp) external onlyOwner {
    updateTimestamp = _updateTimestamp;
  }

  function latestAnswer() external view override returns (int256) {
    return price;
  }

  function latestRoundData() external
  view
  override
  returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  ) {
    return (
      78925697245,
      price,
      updateTimestamp,
      updateTimestamp,
      78925697245
    );
  }

}
