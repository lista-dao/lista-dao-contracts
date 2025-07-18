// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IPancakePair } from "../interfaces/IPancakePair.sol";
import { IPancakeRouter01 } from "../interfaces/IPancakeRouter.sol";

import "./PancakeERC20LpProvider.sol";

/**
 * @title PancakeV2LpProvider
 * @dev Contract for providing PancakeSwap V2 LP tokens as collateral.
 *      It extends PancakeERC20LpProvider to handle the specific logic for V2 LP tokens.
 */
contract PancakeV2LpProvider is PancakeERC20LpProvider, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  /// @dev address of the PancakeSwap router, used for removing V2 liquidity on buy auction
  address public pancakeRouter;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _admin,
    address _manager,
    address _pauser,
    address _pancakeLpToken,
    address _pancakeRouter,
    address _ceToken,
    address _lpToken,
    address _interaction,
    uint256 _discount
  ) external initializer {
    require(_pancakeRouter != address(0), "Invalid Pancake router address");

    pancakeRouter = _pancakeRouter;

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

    uint256 minAmount0 = abi.decode(_data[:32], (uint256));
    uint256 minAmount1 = abi.decode(_data[32:], (uint256));

    // check slippage
    (uint256 amount0, uint256 amount1) = getTokensAmount(_lpAmount);
    require(amount0 >= minAmount0, "Slippage too high for token0");
    require(amount1 >= minAmount1, "Slippage too high for token1");

    IERC20(pancakeLpToken).safeIncreaseAllowance(pancakeRouter, _lpAmount);

    // remove liquidity from PancakeSwap
    (uint256 _amount0, uint256 _amount1) = IPancakeRouter01(pancakeRouter).removeLiquidity(
      token0(),
      token1(),
      _lpAmount,
      minAmount0,
      minAmount1,
      address(this),
      block.timestamp
    );

    if (_amount0 > 0) IERC20(token0()).safeTransfer(_recipient, _amount0);
    if (_amount1 > 0) IERC20(token1()).safeTransfer(_recipient, _amount1);

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

    IPancakePair pair = IPancakePair(pancakeLpToken);
    require(pair.totalSupply() > 0, "Total supply is zero");

    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

    uint256 price0 = resilientOracle.peek(pair.token0());
    uint256 price1 = resilientOracle.peek(pair.token1());

    return (reserve0 * price0 + reserve1 * price1) / pair.totalSupply();
  }

  /// @dev returns the amount of token0 and token1 for given lpAmount
  function getTokensAmount(uint256 _lpAmount) public view override returns (uint256 amount0, uint256 amount1) {
    IPancakePair pair = IPancakePair(pancakeLpToken);
    require(pair.totalSupply() > 0, "Total supply is zero");

    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
    uint256 totalSupply = pair.totalSupply();

    amount0 = (_lpAmount * reserve0) / totalSupply;
    amount1 = (_lpAmount * reserve1) / totalSupply;
  }

  /// @dev Returns the token0 address
  function token0() public view override returns (address) {
    return IPancakePair(pancakeLpToken).token0();
  }

  /// @dev Returns the token1 address
  function token1() public view override returns (address) {
    return IPancakePair(pancakeLpToken).token1();
  }

  /// ------------------ priviliged functions ------------------

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
