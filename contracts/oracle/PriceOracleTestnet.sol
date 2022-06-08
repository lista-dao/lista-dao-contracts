// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IMovingWindowOracle } from "../interfaces/IMovingWindowOracle.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PriceOracleTestnet is Initializable, UUPSUpgradeable, OwnableUpgradeable {
  // FIXME: Uncomment for mainnet
  // address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB MAINNET
  // address public constant USD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // BUSD MAINNET
  // address public constant USD = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // USDC MAINNET
  ///////////////////////////////////////////////////////

  // FIXME: need to be removed for mainnet
  address public constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // WBNB TESTNET
  address public constant USD = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7; // BUSD TESTNET
  // address public constant USD = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // USDT TESTNET
  ///////////////////////////////////////////////////////

  address public tokenIn;
  bool public useBNBPath;
  uint8 public tokenInDecimals;
  uint8 public usdDecimals;
  IMovingWindowOracle public pancakeOracle;

  function initialize(
    address _tokenIn,
    IMovingWindowOracle _pancakeOracle,
    bool _useBNBPath
  ) external initializer {
    __Ownable_init();
    tokenIn = _tokenIn;
    tokenInDecimals = IERC20Metadata(_tokenIn).decimals();
    usdDecimals = IERC20Metadata(USD).decimals();
    pancakeOracle = _pancakeOracle;
    useBNBPath = _useBNBPath;
  }

  function _authorizeUpgrade(address newImplementations) internal override onlyOwner {}

  function peek() public view returns (bytes32, bool) {
    uint256 oneTokenIn = 10**tokenInDecimals;
    uint256 oneTokenOut = 10**usdDecimals;
    uint256 amountOut;
    if (useBNBPath) {
      uint256 bnbAmountOut = pancakeOracle.consult(tokenIn, oneTokenIn, WBNB);
      amountOut = pancakeOracle.consult(WBNB, bnbAmountOut, USD);
    } else {
      amountOut = pancakeOracle.consult(tokenIn, oneTokenIn, USD);
    }
    uint256 price = oneTokenOut / amountOut * 10**18 ;
    return (bytes32(price), true);
  }

  uint256[30] private __gap;
}
