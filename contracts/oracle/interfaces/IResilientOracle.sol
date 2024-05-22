// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IResilientOracle {
  function peek(address asset) external view returns (uint256);
}
