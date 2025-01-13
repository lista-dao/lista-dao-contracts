// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IVBep20Delegate.sol";

contract VenusAdapter is AccessControlUpgradeable, UUPSUpgradeable {
  using SafeERC20 for IERC20;
  address public vaultManager; // vault manager address
  address public token; // token address
  address public vToken; // vToken address
  uint256 public netDepositAmount; // user net deposit amount
  address public feeReceiver; // fee receiver address

  bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role

  event Deposit(uint256 amount);
  event Withdraw(address account, uint256 amount);
  event Harvest(address account, uint256 amount);
  event SetFeeReceiver(address feeReceiver);
  event SetVaultManager(address vaultManager);
  event SetVToken(address vToken);
  event SetToken(address token);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  modifier onlyVaultManager() {
    require(msg.sender == vaultManager, "only VaultManager can call this function");
    _;
  }

  /**
   * @dev initialize contract
   * @param _admin admin address
   * @param _manager manager address
   * @param _vaultManager vault manager address
   * @param _token token address
   * @param _vToken vToken address
   * @param _feeReceiver fee receiver address
   */
  function initialize(
    address _admin,
    address _manager,
    address _vaultManager,
    address _token,
    address _vToken,
    address _feeReceiver
  ) public initializer {
    require(_admin != address(0), "admin cannot be zero address");
    require(_manager != address(0), "manager cannot be zero address");
    require(_vaultManager != address(0), "vaultManager cannot be zero address");
    require(_token != address(0), "token cannot be zero address");
    require(_vToken != address(0), "vToken cannot be zero address");
    require(_feeReceiver != address(0), "feeReceiver cannot be zero address");

    __AccessControl_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    _setupRole(MANAGER, _manager);

    vaultManager = _vaultManager;
    token = _token;
    vToken = _vToken;
    feeReceiver = _feeReceiver;

    emit SetVaultManager(_vaultManager);
    emit SetToken(_token);
    emit SetVToken(_vToken);
    emit SetFeeReceiver(_feeReceiver);
  }

  /**
   * @dev deposit token by vault manager
   * @param amount deposit amount
   */
  function deposit(uint256 amount) external onlyVaultManager {
    require(amount > 0, "deposit amount cannot be zero");
    IERC20(token).safeTransferFrom(vaultManager, address(this), amount);
    IERC20(token).safeIncreaseAllowance(vToken, amount);

    netDepositAmount += amount;

    // deposit to venus pool
    uint256 code = IVBep20Delegate(vToken).mint(amount);
    require(code == 0, "venus mint failed");

    emit Deposit(amount);
  }

  /**
   * @dev withdraw token by vault manager
   * @param account withdraw account
   * @param amount withdraw amount
   */
  function withdraw(address account, uint256 amount) external onlyVaultManager {
    require(amount > 0, "withdraw amount cannot be zero");
    require(amount <= netDepositAmount, "withdraw amount exceeds net deposit");

    netDepositAmount -= amount;

    uint256 before = IERC20(token).balanceOf(address(this));
    uint256 code = IVBep20Delegate(vToken).redeemUnderlying(amount);
    uint256 withdrawAmount = IERC20(token).balanceOf(address(this)) - before;

    require(code == 0, "venus redeemUnderlying failed");
    require(withdrawAmount == amount, "withdraw amount error");

    // transfer token to account
    IERC20(token).safeTransfer(account, amount);

    emit Withdraw(account, amount);
  }

  /**
   * @dev withdraw all token to vault manager
   */
  function withdrawAll() external onlyVaultManager returns (uint256) {
    // harvest interest to fee receiver
    harvest();

    // withdraw all token to vault manager
    netDepositAmount = 0;

    uint256 totalAmount;
    uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));

    if (vTokenAmount > 0) {
      totalAmount = _withdrawFromVenus(vTokenAmount);
    }
    if (totalAmount > 0) {
      IERC20(token).safeTransfer(vaultManager, totalAmount);
      emit Withdraw(vaultManager, totalAmount);
    }
    return totalAmount;
  }

  /**
   * @dev harvest interest to fee receiver
   */
  function harvest() public {
    uint256 totalAmount = IVBep20Delegate(vToken).balanceOfUnderlying(address(this));
    if (totalAmount > netDepositAmount) {
      // calculate interest and redeem amount
      uint256 interest = totalAmount - netDepositAmount;

      uint256 before = IERC20(token).balanceOf(address(this));
      uint256 code = IVBep20Delegate(vToken).redeemUnderlying(interest);
      uint256 harvestAmount = IERC20(token).balanceOf(address(this)) - before;

      require(code == 0, "venus redeemUnderlying failed");
      require(harvestAmount == interest, "harvest interest error");

      IERC20(token).safeTransfer(feeReceiver, interest);

      emit Harvest(feeReceiver, interest);
    }
  }

  function _withdrawFromVenus(uint256 vTokenAmount) private returns (uint256) {
    uint256 before = IERC20(token).balanceOf(address(this));
    IERC20(vToken).safeIncreaseAllowance(vToken, vTokenAmount);
    uint256 code = IVBep20Delegate(vToken).redeem(vTokenAmount);
    require(code == 0, "venus redeem failed");
    return IERC20(token).balanceOf(address(this)) - before;
  }

  /**
   * @dev set fee receiver
   * @param _feeReceiver fee receiver address
   */
  function setFeeReceiver(address _feeReceiver) external onlyRole(MANAGER) {
    require(_feeReceiver != address(0), "feeReceiver cannot be zero address");
    feeReceiver = _feeReceiver;
    emit SetFeeReceiver(_feeReceiver);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
