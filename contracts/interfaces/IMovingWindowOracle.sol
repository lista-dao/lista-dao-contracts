// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMovingWindowOracle {
  function consult(
    address tokenIn,
    uint256 amountIn,
    address tokenOut
  ) external view returns (uint256 amountOut);
}
