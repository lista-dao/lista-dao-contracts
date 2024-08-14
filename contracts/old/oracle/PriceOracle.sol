// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IMovingWindowOracle } from "../../interfaces/IMovingWindowOracle.sol";

contract PriceOracle is Initializable, UUPSUpgradeable, OwnableUpgradeable {
  address public wbnb;
  address public usd;

  address public tokenIn;
  bool public useBNBPath;
  uint8 public tokenInDecimals;
  uint8 public usdDecimals;
  IMovingWindowOracle public pancakeOracle;

  function initialize(
    address _tokenIn,
    IMovingWindowOracle _pancakeOracle,
    bool _useBNBPath,
    address _wbnb,
    address _usd
  ) external initializer {
    __Ownable_init();
    tokenIn = _tokenIn;
    wbnb = _wbnb;
    usd = _usd;
    tokenInDecimals = IERC20Metadata(_tokenIn).decimals();
    usdDecimals = IERC20Metadata(_usd).decimals();
    pancakeOracle = _pancakeOracle;
    useBNBPath = _useBNBPath;
  }

  function _authorizeUpgrade(address newImplementations) internal override onlyOwner {}

  function peek() public view returns (bytes32, bool) {
    uint256 oneTokenIn = 10**tokenInDecimals;
    uint256 oneTokenOut = 10**usdDecimals;
    uint256 amountOut;
    if (useBNBPath) {
      uint256 bnbAmountOut = pancakeOracle.consult(tokenIn, oneTokenIn, wbnb);
      amountOut = pancakeOracle.consult(wbnb, bnbAmountOut, usd);
    } else {
      amountOut = pancakeOracle.consult(tokenIn, oneTokenIn, usd);
    }
    uint256 price = (amountOut * 10**18) / oneTokenOut;
    return (bytes32(price), true);
  }

  uint256[30] private __gap;
}
