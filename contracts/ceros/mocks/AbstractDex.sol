// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { IDex } from "../interfaces/IDex.sol";

// solhint-disable no-empty-blocks
abstract contract AbstractDex is IDex {
  function factory() external pure returns (address) {
    return address(0);
  }

  // solhint-disable-next-line func-name-mixedcase
  function WETH() external pure returns (address) {
    return address(0);
  }

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts) {}

  function swapTokensForExactTokens(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts) {}

  function quote(
    uint256 amountA,
    uint256 reserveA,
    uint256 reserveB
  ) external pure returns (uint256 amountB) {}

  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
  ) external pure returns (uint256 amountOut) {}

  function getAmountIn(
    uint256 amountOut,
    uint256 reserveIn,
    uint256 reserveOut
  ) external pure returns (uint256 amountIn) {}

  function getAmountsIn(uint256 amountOut, address[] calldata path)
    external
    view
    returns (uint256[] memory amounts)
  {}
}
