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

/**
  * @title PancakeERC20LpProvider
  * @dev Abstract contract for providing Pancake V2 or SS LP tokens as collateral.
 */
abstract contract PancakeERC20LpProvider is
  AccessControlEnumerableUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using SafeERC20 for IERC20;

  ///@dev V2/SS LP token address
  address public pancakeLpToken;

  /// @dev ceToken; internal ERC20 token representing the collateral
  address public ceToken;

  /// @dev clisToken; Non-transferable receipt
  ILpToken public lpToken;

  /// @dev address of CDP Interaction contract
  IDao public dao;

  /// @dev scale factor for token to lpToken conversion
  uint256 public discount;

  uint256 public constant ONE = 1e18;
  IResilientOracle public constant resilientOracle = IResilientOracle(0xf3afD82A4071f272F403dC176916141f44E6c750);

  bytes32 public constant MANAGER = keccak256("MANAGER");
  bytes32 public constant PAUSER = keccak256("PAUSER");

  event Deposit(address indexed account, uint256 v2LpAmount);
  event Withdrawal(address indexed account, address indexed recipient, uint256 v2LpAmount);
  event DiscountChanged(uint256 newDiscount);
  event Liquidation(
    address indexed lpToken,
    address indexed recipient,
    uint256 lpAmount,
    uint256 amount0,
    uint256 amount1
  );

  function __ERC20LpProvider_init(
    address _admin,
    address _manager,
    address _pauser,
    address _pancakeLpToken,
    address _ceToken,
    address _lpToken,
    address _interaction,
    uint256 _discount
  ) internal onlyInitializing {
    require(_pancakeLpToken != address(0), "Invalid Pancake LP token address");
    require(IERC20(_pancakeLpToken).totalSupply() > 0, "Pancake LP token must have a non-zero total supply");
    require(IERC20Metadata(_pancakeLpToken).decimals() == 18, "Pancake LP token must have 18 decimals");
    require(_ceToken != address(0), "Invalid ceToken address");
    require(_lpToken != address(0), "Invalid lpToken address");
    require(_interaction != address(0), "Invalid interaction address");
    require(_discount > 0 && _discount <= ONE, "Discount must be between 0 and 1e18");

    pancakeLpToken = _pancakeLpToken;
    ceToken = _ceToken;
    lpToken = ILpToken(_lpToken);
    dao = IDao(_interaction);
    discount = _discount;

    emit DiscountChanged(_discount);

    __Pausable_init();
    __AccessControl_init();
    __ReentrancyGuard_init();

    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(MANAGER, _manager);
    _grantRole(PAUSER, _pauser);
  }

  /**
   * @dev Deposit Pancake V2 LP Token as collateral.
   * @param _amount amount of Pancake V2 LP Token to deposit
   * @return _amount amount of LP token deposited
   */
  function provide(uint256 _amount) external whenNotPaused nonReentrant returns (uint256) {
    require(_amount > 0, "zero deposit amount");

    // Mint ceToken and join CDP
    ICertToken(ceToken).mint(address(this), _amount);
    dao.deposit(msg.sender, ceToken, _amount);

    // Mint Non-transferable receipt to caller
    lpToken.mint(msg.sender, _amount);

    emit Deposit(msg.sender, _amount);
    return _amount;
  }

  /**
   * @dev Withdraw Pancake V2 LP Token from collateral.
   * @param _recipient address to receive Pancake V2 LP Token
   * @param _amount amount of V2 LP Token to withdraw
   */
  function release(address _recipient, uint256 _amount) external whenNotPaused nonReentrant returns (uint256) {
    require(_recipient != address(0), "Invalid recipient address");
    require(_amount > 0, "Zero withdraw amount");

    // Exit CDP and burn ceToken & clisToken
    dao.withdraw(msg.sender, ceToken, _amount);
    ICertToken(ceToken).burn(address(this), _amount);
    lpToken.burn(msg.sender, _amount);

    // Transfer Pancake LP Token to caller
    IERC20(pancakeLpToken).safeTransfer(_recipient, _amount);
    emit Withdrawal(msg.sender, _recipient, _amount);
    return _amount;
  }

  /**
   * @dev Start auction. Burn clisToken
   * @param _account collateral token holder
   * @param _lpAmount clisToken amount to burn
   */
  function daoBurn(address _account, uint256 _lpAmount) external nonReentrant whenNotPaused {
    require(msg.sender == address(dao), "Only Interaction can call this function");
    require(_account != address(0));

    if (_lpAmount > 0) {
      lpToken.burn(_account, _lpAmount);
    }
  }

  /// @dev Buy from auction. Transfer bidded collateral to recipient in the form of token0 and token1.
  function liquidation(address _recipient, uint256 _lpAmount, bytes calldata _data) external virtual {}

  /// @dev Returns the V2 LP token price for using in Spotter contract
  function peek() external view virtual returns (bytes32, bool) {}

  /// @dev Returns the V2 LP token price
  function getLpPrice() external view virtual returns (uint256) {}

  /// @dev Returns the amount of token0 and token1 for given LP token amount
  function getTokensAmount(uint256 _lpAmount) external view virtual returns (uint256, uint256) {}

  /// @dev Returns the token0 address
  function token0() external view virtual returns (address) {}

  /// @dev Returns the token1 address
  function token1() external view virtual returns (address) {}

  /// ------------------------------------ priviliged functions ------------------------------------ ///

  function setDiscount(uint256 _discount) external onlyRole(MANAGER) {
    require(_discount > 0 && _discount <= ONE, "Discount must be between 0 and 1e18");
    require(discount != _discount, "New discount must be different from the current one");

    discount = _discount;

    emit DiscountChanged(_discount);
  }

  /// @dev pause the contract
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /// @dev resume contract
  function unpause() external onlyRole(MANAGER) {
    _unpause();
  }
}
