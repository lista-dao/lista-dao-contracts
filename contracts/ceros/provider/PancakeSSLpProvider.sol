// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { IDao } from "../interfaces/IDao.sol";
import { IResilientOracle } from "../../oracle/interfaces/IResilientOracle.sol";
import { ICertToken } from "../interfaces/ICertToken.sol";
import { ILpToken } from "../interfaces/ILpToken.sol";

import { IStakingHub } from "../../pcsLp/interfaces/IStakingHub.sol";
import { IV2Wrapper } from "../../pcsLp/interfaces/IV2Wrapper.sol";
import { IStableSwap, IStableSwapPoolInfo } from "../../pcsLp/interfaces/IStableSwap.sol";

import { ERC20LpRewardDistributor } from "../../pcsLp/ERC20LpRewardDistributor.sol";

contract PancakeSSLpProvider is ERC20LpRewardDistributor, ReentrancyGuardUpgradeable, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  /// @dev ceToken; internal ERC20 token representing the collateral
  address public ceToken;

  /// @dev clisToken; Non-transferable receipt
  ILpToken public lpToken;

  /// @dev address of Interaction contract
  IDao public dao;

  address public stableSwapPool;

  address public stableSwapPoolInfo;

  /// @dev scale factor for token to lpToken conversion
  uint256 public discount;

  IResilientOracle public constant resilientOracle = IResilientOracle(0xf3afD82A4071f272F403dC176916141f44E6c750);

  bytes32 public constant MANAGER = keccak256("MANAGER");
  bytes32 public constant BOT = keccak256("BOT");

  uint256 private constant ONE = 1e18;

  event Deposit(address indexed account, uint256 v2LpAmount);
  event Withdrawal(address indexed account, address indexed recipient, uint256 v2LpAmount);
  event Liquidation(
    address indexed lpToken,
    address indexed recipient,
    uint256 lpAmount,
    uint256 amount0,
    uint256 amount1
  );
  event DiscountChanged(uint256 newDiscount);

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
    address _stableSwapPool,
    address _stableSwapPoolInfo,
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
    require(IERC20(_pancakeLpToken).totalSupply() > 0, "Pancake LP token must have a non-zero total supply");
    require(IERC20Metadata(_pancakeLpToken).decimals() == 18, "Pancake LP token must have 18 decimals");
    require(_stableSwapPool != address(0), "Invalid stable swap pool address");
    require(_stableSwapPoolInfo != address(0), "Invalid stable swap pool info address");
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
    stableSwapPool = _stableSwapPool;
    stableSwapPoolInfo = _stableSwapPoolInfo;
    pancakeLpToken = _pancakeLpToken;
    discount = _discount;

    emit DiscountChanged(_discount);
  }

  function provide(uint256 _amount) external whenNotPaused nonReentrant returns (uint256) {
    require(_amount > 0, "zero deposit amount");

    // 1. transfer LP and do farming
    _deposit(_amount);

    // 2. mint ceToken and join CDP
    ICertToken(ceToken).mint(address(this), _amount);
    dao.deposit(msg.sender, ceToken, _amount);

    // 3. mint Non-transferable receipt to caller
    lpToken.mint(msg.sender, _amount);

    emit Deposit(msg.sender, _amount);
    return _amount;
  }

  /**
   * @param _recipient address to receive Pancake V2 LP Token
   * @param _amount amount of V2 LP Token to withdraw
   */
  function release(address _recipient, uint256 _amount) external whenNotPaused nonReentrant returns (uint256) {
    require(_recipient != address(0), "Invalid recipient address");
    require(_amount > 0, "Zero withdraw amount");

    // 1. unstake LP from farming
    _withdraw(_amount);

    // 2. exit CDP and burn ceToken & clisToken
    dao.withdraw(msg.sender, ceToken, _amount);
    ICertToken(ceToken).burn(address(this), _amount);
    lpToken.burn(msg.sender, _amount);

    // 3. transfer Pancake LP Token to caller
    IERC20(pancakeLpToken).safeTransfer(_recipient, _amount);
    emit Withdrawal(msg.sender, _recipient, _amount);
    return _amount;
  }

  /**
   * @dev Start auction. Burn clisToken and unstake LP from farming.
   * @param _account collateral token holder
   * @param _lpAmount lpToken amount to burn
   */
  function daoBurn(address _account, uint256 _lpAmount) external nonReentrant whenNotPaused {
    require(msg.sender == address(dao), "Only Interaction can call this function");
    require(_account != address(0));
    require(_lpAmount > 0, "Zero lp amount");

    // 1. unstake LP from farming
    _withdraw(_lpAmount);

    lpToken.burn(_account, _lpAmount);
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
  ) external nonReentrant whenNotPaused {
    require(msg.sender == address(dao), "Only Interaction can call this function");
    require(_recipient != address(0));
    require(_data.length == 64, "Invalid data length");

    // remove liquidity from PancakeSwap
    uint256 minAmount0 = abi.decode(_data[:32], (uint256));
    uint256 minAmount1 = abi.decode(_data[32:], (uint256));

    // check slippage
    (uint256 _amount0, uint256 _amount1) = getCoinsAmount(_lpAmount);
    require(_amount0 >= minAmount0, "Slippage too high for token0");
    require(_amount1 >= minAmount1, "Slippage too high for token1");

    address token0 = coins(0);
    address token1 = coins(1);

    uint256 balance0Before = IERC20(token0).balanceOf(address(this));
    uint256 balance1Before = IERC20(token1).balanceOf(address(this));
    IStableSwap(stableSwapPool).remove_liquidity(_lpAmount, [minAmount0, minAmount1]);

    _amount0 = IERC20(token0).balanceOf(address(this)) - balance0Before;
    _amount1 = IERC20(token1).balanceOf(address(this)) - balance1Before;

    // transfer tokens to recipient
    if (_amount0 > 0) IERC20(token0).safeTransfer(_recipient, _amount0);
    if (_amount1 > 0) IERC20(token1).safeTransfer(_recipient, _amount1);

    emit Liquidation(pancakeLpToken, _recipient, _lpAmount, _amount0, _amount1);
  }

  /// @dev returns the V2 LP token price for using in spotter
  function peek() external view returns (bytes32, bool) {
    uint256 realPrice = getLpPrice();
    uint256 price = (realPrice * discount) / ONE;

    return (bytes32(uint(price) * 1e10), price > 0);
  }

  /// @dev returns the Pancake LP ERC20 token price in 8 decimal format
  function getLpPrice() public view returns (uint256) {
    require(pancakeLpToken != address(0), "Pancake LP token not set");

    uint256[2] memory coinsAmount = IStableSwapPoolInfo(stableSwapPoolInfo).calc_coins_amount(stableSwapPool, 1 ether);
    uint256 _token0Amount = coinsAmount[0];
    uint256 _token1Amount = coinsAmount[1];

    uint256 price0 = resilientOracle.peek(coins(0));
    uint256 price1 = resilientOracle.peek(coins(1));

    return (_token0Amount * price0 + _token1Amount * price1) / 1 ether;
  }

  /**
   * @dev Get amount of coins for given LP token amount.
   * @param _lpAmount amount of LP token
   */
  function getCoinsAmount(uint256 _lpAmount) public view returns (uint256 _amount0, uint256 _amount1) {
    uint256[2] memory coinsAmount = IStableSwapPoolInfo(stableSwapPoolInfo).calc_coins_amount(
      stableSwapPool,
      _lpAmount
    );
    _amount0 = coinsAmount[0];
    _amount1 = coinsAmount[1];
  }

  function coins(uint256 index) public view returns (address) {
    return IStableSwap(stableSwapPool).coins(index);
  }

  /// ------------------ priviliged functions ------------------

  function setDiscount(uint256 _discount) external onlyRole(MANAGER) {
    require(_discount > 0 && _discount <= ONE, "Discount must be between 0 and 1e18");
    require(discount != _discount, "New discount must be different from the current one");

    discount = _discount;

    emit DiscountChanged(_discount);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
