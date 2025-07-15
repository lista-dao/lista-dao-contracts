// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title The interface for LpUsd
interface ILpUsd is IERC20 {
  function mint(address account, uint256 amount) external;
  function burn(address account, uint256 amount) external;
}
