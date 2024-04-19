// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import "./interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockSourceOracle is IMockSourceOracle, Ownable {

  int256 public price;

  function setPrice(int256 _price) external onlyOwner {
    price = _price;
  }

  function latestAnswer() external view override returns (int256) {
    return price;
  }

}
