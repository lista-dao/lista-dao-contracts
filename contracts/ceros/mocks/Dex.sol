// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AbstractDex } from "./AbstractDex.sol";

contract Dex is AbstractDex {
  address public wNative;
  address public otherToken;
  uint256 public nativeAmount;
  uint256 public otherTokenAmount;
  uint256 public rate;

  constructor(address _wNative, address _otherToken) {
    wNative = _wNative;
    otherToken = _otherToken;
  }

  function getAmountsOut(uint256 amountIn, address[] calldata path)
    public
    view
    returns (uint256[] memory amounts)
  {
    amounts = new uint256[](2);
    amounts[0] = amountIn;
    _checkPath(path);
    if (path[0] == wNative) {
      amounts[1] = (amountIn * rate) / 1e18;
    } else {
      amounts[1] = (amountIn * 1e18) / rate;
    }
  }

  function swapExactETHForTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable returns (uint256[] memory amounts) {
    require(deadline >= block.timestamp, "deadline revert");
    require(path[0] == wNative, "Unsupported path");
    uint256 amountIn = msg.value;
    amounts = getAmountsOut(amountIn, path);
    require(amountOutMin <= amounts[1], "min amount out error");
    nativeAmount += amounts[0];
    IERC20(otherToken).transfer(to, amounts[1]);
  }

  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts) {
    require(deadline >= block.timestamp, "deadline revert");
    require(path[1] == wNative, "Unsupported path");
    amounts = getAmountsOut(amountIn, path);
    require(amountOutMin <= amounts[1], "min amount out error");
    otherTokenAmount += amounts[0];
    _sendValue(to, amounts[1]);
  }

  function addLiquidity(uint256 otherTokenAmt) external payable {
    IERC20(otherToken).transferFrom(msg.sender, address(this), otherTokenAmt);
    nativeAmount += msg.value;
    otherTokenAmount += otherTokenAmt;
  }

  function setRate(uint256 _rate) external {
    rate = _rate;
  }

  function _checkPath(address[] calldata path) internal view {
    require(path.length == 2, "unsupported path");
    require(
      (path[0] == wNative && path[1] == otherToken) ||
        (path[1] == wNative && path[0] == otherToken),
      "unsupported path"
    );
  }

  function _sendValue(address receiver, uint256 amount) internal {
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = payable(receiver).call{ value: amount }("");
    require(success, "unable to send value, recipient may have reverted");
  }
}
