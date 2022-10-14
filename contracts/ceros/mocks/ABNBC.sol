// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { MintableERC20 } from "./MintableERC20.sol";

contract ABNBC is MintableERC20 {
  uint256 public ratio;

  function setRatio(uint256 _ratio) external {
    ratio = _ratio;
  }
}
