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

import { ERC20LpRewardDistributor } from "../../pcsLp/ERC20LpRewardDistributor.sol";

abstract contract PancakeERC20LpProvider is ERC20LpRewardDistributor, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;
  /// @dev ceToken; internal ERC20 token representing the collateral
  address public ceToken;

  /// @dev clisToken; Non-transferable receipt
  ILpToken public lpToken;

  /// @dev address of Interaction contract
  IDao public dao;

  /// @dev scale factor for token to lpToken conversion
  uint256 public discount;

  uint256 public constant ONE = 1e18;
  IResilientOracle public constant resilientOracle = IResilientOracle(0xf3afD82A4071f272F403dC176916141f44E6c750);

  bytes32 public constant MANAGER = keccak256("MANAGER");
  bytes32 public constant BOT = keccak256("BOT");

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
   * @param _lpAmount clisToken amount to burn
   */
  function daoBurn(address _account, uint256 _lpAmount) external nonReentrant whenNotPaused {
    require(msg.sender == address(dao), "Only Interaction can call this function");
    require(_account != address(0));
    require(_lpAmount > 0, "Zero lpToken amount");

    _withdraw(_lpAmount);

    lpToken.burn(_account, _lpAmount);
  }

  function liquidation(address _recipient, uint256 _lpAmount, bytes calldata _data) external virtual {}

  function peek() external view virtual returns (bytes32, bool) {}

  function getLpPrice() external view virtual returns (uint256) {}

  function getCoinsAmount(uint256 _lpAmount) external view virtual returns (uint256, uint256) {}

  /// ------------------ priviliged functions ------------------

  function setDiscount(uint256 _discount) external onlyRole(MANAGER) {
    require(_discount > 0 && _discount <= ONE, "Discount must be between 0 and 1e18");
    require(discount != _discount, "New discount must be different from the current one");

    discount = _discount;

    emit DiscountChanged(_discount);
  }
}
