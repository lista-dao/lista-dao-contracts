// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IV2Wrapper } from "../../pcsLp/interfaces/IV2Wrapper.sol";
import { IStableSwap, IStableSwapPoolInfo } from "../../pcsLp/interfaces/IStableSwap.sol";

import "./PancakeERC20LpProvider.sol";

/**
 * @title PancakeSSLpProvider
 * @dev Contract for providing PancakeSwap StableSwap LP tokens as collateral.
 *      It extends PancakeERC20LpProvider to handle the specific logic for StableSwap LP tokens.
 */
contract PancakeSSLpProvider is PancakeERC20LpProvider, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  /// @dev address of the StableSwap pool, used for removing SS liquidity on buy auction
  address public stableSwapPool;

  /// @dev address of the StableSwap pool info contract, used for calculating coins amount
  address public stableSwapPoolInfo;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _admin,
    address _manager,
    address _pauser,
    address _pancakeLpToken,
    address _stableSwapPool,
    address _stableSwapPoolInfo,
    address _ceToken,
    address _lpToken,
    address _interaction,
    uint256 _discount
  ) external initializer {
    require(_stableSwapPool != address(0), "Invalid stable swap pool address");
    require(_stableSwapPoolInfo != address(0), "Invalid stable swap pool info address");

    stableSwapPool = _stableSwapPool;
    stableSwapPoolInfo = _stableSwapPoolInfo;

    __ERC20LpProvider_init(_admin, _manager, _pauser, _pancakeLpToken, _ceToken, _lpToken, _interaction, _discount);
  }

  /**
   * @dev Buy from auction. Transfer bidded collateral to recipient in the form of token0 and token1.
   * @param _recipient recipient address
   * @param _lpAmount lp amount to liquidate
   * @param _data packed minAmount0 and minAmount1 for removeLiquidity
   */
  function liquidation(
    address _recipient,
    uint256 _lpAmount,
    bytes calldata _data
  ) external override nonReentrant whenNotPaused {
    require(msg.sender == address(dao), "Only Interaction can call this function");
    require(_recipient != address(0));
    require(_data.length == 64, "Invalid data length");

    // remove liquidity from PancakeSwap
    uint256 minAmount0 = abi.decode(_data[:32], (uint256));
    uint256 minAmount1 = abi.decode(_data[32:], (uint256));

    // check slippage
    (uint256 _amount0, uint256 _amount1) = getTokensAmount(_lpAmount);
    require(_amount0 >= minAmount0, "Slippage too high for token0");
    require(_amount1 >= minAmount1, "Slippage too high for token1");

    IERC20 _token0 = IERC20(token0());
    IERC20 _token1 = IERC20(token1());

    uint256 balance0Before = _token0.balanceOf(address(this));
    uint256 balance1Before = _token1.balanceOf(address(this));
    IStableSwap(stableSwapPool).remove_liquidity(_lpAmount, [minAmount0, minAmount1]);

    _amount0 = _token0.balanceOf(address(this)) - balance0Before;
    _amount1 = _token1.balanceOf(address(this)) - balance1Before;

    // transfer tokens to recipient
    if (_amount0 > 0) _token0.safeTransfer(_recipient, _amount0);
    if (_amount1 > 0) _token1.safeTransfer(_recipient, _amount1);

    emit Liquidation(pancakeLpToken, _recipient, _lpAmount, _amount0, _amount1);
  }

  /// @dev returns the V2 LP token price for using in spotter
  function peek() external view override returns (bytes32, bool) {
    uint256 realPrice = getLpPrice();
    uint256 price = (realPrice * discount) / ONE;

    return (bytes32(uint(price) * 1e10), price > 0);
  }

  /// @dev returns the Pancake LP ERC20 token price in 8 decimal format
  function getLpPrice() public view override returns (uint256) {
    require(pancakeLpToken != address(0), "Pancake LP token not set");

    uint256[2] memory coinsAmount = IStableSwapPoolInfo(stableSwapPoolInfo).calc_coins_amount(stableSwapPool, 1 ether);
    uint256 _token0Amount = coinsAmount[0];
    uint256 _token1Amount = coinsAmount[1];

    uint256 price0 = resilientOracle.peek(token0());
    uint256 price1 = resilientOracle.peek(token1());

    return (_token0Amount * price0 + _token1Amount * price1) / 1 ether;
  }

  /**
   * @dev Get amount of coins for given LP token amount.
   * @param _lpAmount amount of LP token
   */
  function getTokensAmount(uint256 _lpAmount) public view override returns (uint256 _amount0, uint256 _amount1) {
    uint256[2] memory coinsAmount = IStableSwapPoolInfo(stableSwapPoolInfo).calc_coins_amount(
      stableSwapPool,
      _lpAmount
    );
    _amount0 = coinsAmount[0];
    _amount1 = coinsAmount[1];
  }

  /// @dev Returns the token0 address
  function token0() public view override returns (address) {
    return IStableSwap(stableSwapPool).coins(0);
  }

  /// @dev Returns the token1 address
  function token1() public view override returns (address) {
    return IStableSwap(stableSwapPool).coins(1);
  }

  /// ------------------ priviliged functions ------------------

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
