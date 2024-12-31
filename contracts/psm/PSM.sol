// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IVaultManager.sol";

contract PSM is AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  address public vaultManager; // VaultManager address
  address public token; // token address
  uint256 public sellFee; // sell fee rate
  uint256 public buyFee; // buy fee rate
  address public feeReceiver; // fee receiver address
  address public lisUSD; // lisUSD address

  uint256 public dailyLimit; // daily buy limit
  uint256 public minSell; // min sell amount
  uint256 public minBuy; // min buy amount

  uint256 public lastBuyDay; // last buy day
  uint256 public dayBuyUsed; // day buy used

  uint256 public fees; // total fee

  uint256 public constant FEE_PRECISION = 10000;

  bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
  bytes32 public constant PAUSER = keccak256("PAUSER"); // pause role

  event SetBuyFee(uint256 buyFee);
  event SetSellFee(uint256 sellFee);
  event SetFeeReceiver(address feeReceiver);
  event BuyToken(address account, uint256 realAmount, uint256 fee);
  event SellToken(address account, uint256 realAmount, uint256 fee);
  event SetDailyLimit(uint256 dailyLimit);
  event SetMinSell(uint256 minSell);
  event SetMinBuy(uint256 minBuy);
  event SetVaultManager(address vaultManager);
  event EmergencyWithdraw(address token, uint256 amount);
  event SetToken(address token);
  event SetLisUSD(address lisUSD);
  event Harvest(uint256 fees);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev initialize contract
   * @param _admin admin address
   * @param _manager manager address
   * @param _token token address
   * @param _feeReceiver fee receiver address
   * @param _lisUSD lisUSD address
   * @param _sellFee sell fee
   * @param _buyFee buy fee
   * @param _minSell min sell amount
   * @param _minBuy min buy amount
   */
  function initialize(
    address _admin,
    address _manager,
    address _pauser,
    address _token,
    address _feeReceiver,
    address _lisUSD,
    uint256 _sellFee,
    uint256 _buyFee,
    uint256 _dailyLimit,
    uint256 _minSell,
    uint256 _minBuy
  ) public initializer {
    require(_admin != address(0), "admin cannot be zero address");
    require(_manager != address(0), "manager cannot be zero address");
    require(_pauser != address(0), "pauser cannot be zero address");
    require(_token != address(0), "token cannot be zero address");
    require(_feeReceiver != address(0), "feeReceiver cannot be zero address");
    require(_lisUSD != address(0), "lisUSD cannot be zero address");
    require(_sellFee <= FEE_PRECISION, "sellFee must be less or equal than FEE_PRECISION");
    require(_buyFee <= FEE_PRECISION, "buyFee must be less or equal than FEE_PRECISION");
    require(_dailyLimit >= _minBuy, "dailyLimit must be greater or equal than minBuy");

    __AccessControl_init();
    __Pausable_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    _setupRole(MANAGER, _manager);
    _setupRole(PAUSER, _pauser);

    token = _token;
    sellFee = _sellFee;
    buyFee = _buyFee;
    feeReceiver = _feeReceiver;
    lisUSD = _lisUSD;

    dailyLimit = _dailyLimit;
    minSell = _minSell;
    minBuy = _minBuy;

    emit SetBuyFee(_buyFee);
    emit SetSellFee(_sellFee);
    emit SetFeeReceiver(_feeReceiver);
    emit SetDailyLimit(_dailyLimit);
    emit SetMinSell(_minSell);
    emit SetMinBuy(_minBuy);
    emit SetToken(_token);
    emit SetLisUSD(_lisUSD);
  }

  /**
   * @dev sell token to get lisUSD
   * @param amount token amount
   */
  function sell(uint256 amount) external whenNotPaused {
    require(amount >= minSell, "amount smaller than minSell");
    // calculate fee and real amount
    uint256 fee = Math.mulDiv(amount, sellFee, FEE_PRECISION);
    uint256 realAmount = amount - fee;

    // check sell limit
    require(amount <= getTotalSellLimit(), "exceed sell limit");

    // transfer token from user
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    // transfer lisUSD to user
    IERC20(lisUSD).safeTransfer(msg.sender, realAmount);

    // deposit token to vault manager
    IERC20(token).safeIncreaseAllowance(vaultManager, amount);
    IVaultManager(vaultManager).deposit(amount);

    // transfer fee to fee receiver
    if (fee > 0) {
      fees += fee;
    }
    emit SellToken(msg.sender, realAmount, fee);
  }

  /**
   * @dev buy token with lisUSD
   * @param amount lisUSD amount
   */
  function buy(uint256 amount) external whenNotPaused {
    // check buy limit
    checkAndUpdateBuyUsed(amount);

    // calculate fee and real amount
    uint256 fee = Math.mulDiv(amount, buyFee, FEE_PRECISION);
    uint256 realAmount = amount - fee;

    // transfer lisUSD from user and withdraw token from vault manager
    if (realAmount > 0) {
      IERC20(lisUSD).safeTransferFrom(msg.sender, address(this), amount);
      IVaultManager(vaultManager).withdraw(msg.sender, realAmount);
    }

    // transfer fee to fee receiver
    if (fee > 0) {
      fees += fee;
    }
    emit BuyToken(msg.sender, realAmount, fee);
  }

  // check buy limit
  function checkBuyLimit(uint256 amount) public view returns (bool) {
    // check min buy amount
    if (amount < minBuy) {
      return false;
    }
    // check daily buy limit
    if (getDay() == lastBuyDay && dayBuyUsed + amount > dailyLimit) {
      return false;
    }
    if (getDay() != lastBuyDay && amount > dailyLimit) {
      return false;
    }
    return true;
  }

  // check and update buy used
  function checkAndUpdateBuyUsed(uint256 amount) private {
    require(checkBuyLimit(amount), "amount smaller than minBuy or exceed buy limit");

    // update total sell and buy used
    if (getDay() != lastBuyDay) {
      lastBuyDay = getDay();
      dayBuyUsed = 0;
    }

    dayBuyUsed += amount;
  }

  // get day
  function getDay() public view returns (uint256) {
    return block.timestamp / 1 days;
  }

  /**
   * @dev set vault manager address
   * @param _vaultManager vault manager address
   */
  function setVaultManager(address _vaultManager) external onlyRole(MANAGER) {
    require(_vaultManager != address(0), "VaultManager cannot be zero address");
    require(_vaultManager != vaultManager, "VaultManager already set");
    vaultManager = _vaultManager;
    emit SetVaultManager(_vaultManager);
  }

  /**
   * @dev set buy fee
   * @param _buyFee buy fee
   */
  function setBuyFee(uint256 _buyFee) external onlyRole(MANAGER) {
    require(_buyFee <= FEE_PRECISION, "buyFee must be less or equal than FEE_PRECISION");
    buyFee = _buyFee;
    emit SetBuyFee(_buyFee);
  }

  /**
   * @dev set sell fee
   * @param _sellFee sell fee
   */
  function setSellFee(uint256 _sellFee) external onlyRole(MANAGER) {
    require(_sellFee <= FEE_PRECISION, "sellFee must be less or equal than FEE_PRECISION");
    sellFee = _sellFee;
    emit SetSellFee(_sellFee);
  }

  /**
   * @dev set fee receiver address
   * @param _feeReceiver fee receiver address
   */
  function setFeeReceiver(address _feeReceiver) external onlyRole(MANAGER) {
    require(_feeReceiver != address(0), "feeReceiver cannot be zero address");
    feeReceiver = _feeReceiver;
    emit SetFeeReceiver(_feeReceiver);
  }

  /**
   * @dev set daily buy limit
   * @param _dailyLimit daily limit
   */
  function setDailyLimit(uint256 _dailyLimit) external onlyRole(MANAGER) {
    require(_dailyLimit >= minBuy, "dailyLimit must be greater or equal than minBuy");

    dailyLimit = _dailyLimit;
    emit SetDailyLimit(_dailyLimit);
  }

  /**
   * @dev set min sell amount
   * @param _minSell min sell amount
   */
  function setMinSell(uint256 _minSell) external onlyRole(MANAGER) {
    minSell = _minSell;
    emit SetMinSell(_minSell);
  }

  /**
   * @dev set min buy amount
   * @param _minBuy min buy amount
   */
  function setMinBuy(uint256 _minBuy) external onlyRole(MANAGER) {
    require(dailyLimit >= _minBuy, "minBuy must be less or equal than dailyLimit");

    minBuy = _minBuy;
    emit SetMinBuy(_minBuy);
  }

  /**
   * @dev get total buy limit
   * @return total buy limit
   */
  function getTotalBuyLimit() external view returns (uint256) {
    return IVaultManager(vaultManager).getTotalNetDepositAmount();
  }

  /**
   * @dev get total sell limit
   * @return total sell limit
   */
  function getTotalSellLimit() public view returns (uint256) {
    return IERC20(lisUSD).balanceOf(address(this)) - fees;
  }

  /**
   * @dev get day buy left
   * @return day buy left
   */
  function getDayBuyLeft() external view returns (uint256) {
    if (getDay() == lastBuyDay) {
      return dailyLimit - dayBuyUsed;
    }
    return dailyLimit;
  }

  /**
   * @dev harvest fees
   */
  function harvest() external {
    if (fees > 0) {
      uint256 _fees = fees;
      fees = 0;
      IERC20(lisUSD).safeTransfer(feeReceiver, _fees);

      emit Harvest(_fees);
    }
  }

  /**
   * @dev pause contract
   */
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /**
   * @dev unpause contract
   */
  function unpause() external onlyRole(MANAGER) {
    _unpause();
  }

  /**
   * @dev allows admin to withdraw tokens for emergency or recover any other mistaken tokens.
   * @param _token token address
   * @param _amount token amount
   */
  function emergencyWithdraw(address _token, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (_token == address(0)) {
      (bool success, ) = payable(msg.sender).call{ value: _amount }("");
      require(success, "Withdraw failed");
    } else {
      IERC20(_token).safeTransfer(msg.sender, _amount);
    }
    emit EmergencyWithdraw(_token, _amount);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
