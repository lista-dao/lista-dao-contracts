// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IPancakePair } from "../interfaces/IPancakePair.sol";
import { IPancakeRouter01 } from "../interfaces/IPancakeRouter.sol";

import "./PancakeERC20LpProvider.sol";

contract PancakeV2LpProvider is PancakeERC20LpProvider, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  /// @dev address of the PancakeSwap router, used for removing liquidity on buy auction
  address public pancakeRouter;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _admin,
    address _manager,
    address _bot,
    address _pauser,
    address _pancakeLpToken,
    address _pancakeRouter,
    address _stakingHub,
    address _ceToken,
    address _lpToken,
    address _dao,
    uint256 _discount
  ) external initializer {
    require(_admin != address(0), "Invalid admin address");
    require(_manager != address(0), "Invalid manager address");
    require(_bot != address(0), "Invalid bot address");
    require(_pauser != address(0), "Invalid pauser address");
    require(_pancakeLpToken != address(0), "Invalid Pancake LP token address");
    require(IPancakePair(_pancakeLpToken).totalSupply() > 0, "Pancake LP token must have a non-zero total supply");
    require(IPancakePair(_pancakeLpToken).decimals() == 18, "Pancake LP token must have 18 decimals");
    require(_pancakeRouter != address(0), "Invalid Pancake router address");
    require(_stakingHub != address(0), "Invalid staking hub address");
    require(_ceToken != address(0), "Invalid ceToken address");
    require(_lpToken != address(0), "Invalid lpToken address");
    require(_dao != address(0), "Invalid dao address");
    require(_discount > 0 && _discount <= ONE, "Discount must be between 0 and 1e18");

    __Pausable_init();
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(MANAGER, _manager);
    _grantRole(BOT, _bot);
    _grantRole(PAUSER, _pauser);

    ceToken = _ceToken;
    lpToken = ILpToken(_lpToken);
    dao = IDao(_dao);

    stakingHub = _stakingHub;
    pancakeLpToken = _pancakeLpToken;
    pancakeRouter = _pancakeRouter;
    discount = _discount;

    emit DiscountChanged(_discount);
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
    (uint256 amount0, uint256 amount1) = getCoinsAmount(_lpAmount);
    require(amount0 >= minAmount0, "Slippage too high for token0");
    require(amount1 >= minAmount1, "Slippage too high for token1");

    // remove liquidity
    address token0 = IPancakePair(pancakeLpToken).token0();
    address token1 = IPancakePair(pancakeLpToken).token1();

    IERC20(pancakeLpToken).safeIncreaseAllowance(pancakeRouter, _lpAmount);

    // remove liquidity from PancakeSwap
    (uint256 _amount0, uint256 _amount1) = IPancakeRouter01(pancakeRouter).removeLiquidity(
      token0,
      token1,
      _lpAmount,
      minAmount0,
      minAmount1,
      address(this),
      block.timestamp
    );

    if (_amount0 > 0) IERC20(token0).safeTransfer(_recipient, _amount0);
    if (_amount1 > 0) IERC20(token1).safeTransfer(_recipient, _amount1);

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
  function getCoinsAmount(uint256 _lpAmount) public view override returns (uint256 amount0, uint256 amount1) {
    IPancakePair pair = IPancakePair(pancakeLpToken);
    require(pair.totalSupply() > 0, "Total supply is zero");

    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
    uint256 totalSupply = pair.totalSupply();

    amount0 = (_lpAmount * reserve0) / totalSupply;
    amount1 = (_lpAmount * reserve1) / totalSupply;
  }

  /// ------------------ priviliged functions ------------------

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
