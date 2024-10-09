pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/HayLike.sol";

contract PSM is AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    address public vaultManager; // VaultManager address
    address public token; // token address
    uint256 public sellFee; // sell fee rate
    uint256 public buyFee; // buy fee rate
    address public feeReceiver; // fee receiver address
    address public lisUSD; // lisUSD address

    uint256 public sellLimit; // total sell limit
    uint256 public buyLimit;  // total buy limit
    uint256 public dailyLimit; // daily buy limit
    uint256 public minSell; // min sell amount
    uint256 public minBuy; // min buy amount

    uint256 public lastBuyDay; // last buy day
    uint256 public dayBuyUsed; // day buy used
    uint256 public totalBuyUsed; // total buy used
    uint256 public totalSellUsed; // total sell used

    uint256 public constant FEE_PRECISION = 10000;

    bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
    bytes32 public constant PAUSE = keccak256("PAUSE"); // pause role

    event SetBuyFee(uint256 buyFee);
    event SetSellFee(uint256 sellFee);
    event SetFeeReceiver(address feeReceiver);
    event Buytoken(address account, uint256 realAmount, uint256 fee);
    event Selltoken(address account, uint256 realAmount, uint256 fee);
    event SetSellLimit(uint256 sellLimit);
    event SetBuyLimit(uint256 buyLimit);
    event SetDailyLimit(uint256 dailyLimit);
    event SetMinSell(uint256 minSell);
    event SetMinBuy(uint256 minBuy);
    event SetVaultManager(address vaultManager);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
      * @dev initialize contract
      * @param _token token address
      * @param _feeReceiver fee receiver address
      * @param _lisUSD lisUSD address
      * @param _sellFee sell fee
      * @param _buyFee buy fee
      * @param _sellLimit sell limit
      * @param _buyLimit buy limit
      * @param _minSell min sell amount
      * @param _minBuy min buy amount
      */
    function initialize(
        address _token,
        address _feeReceiver,
        address _lisUSD,
        uint256 _sellFee,
        uint256 _buyFee,
        uint256 _sellLimit,
        uint256 _buyLimit,
        uint256 _dailyLimit,
        uint256 _minSell,
        uint256 _minBuy
    ) public initializer {
        require(_token != address(0), "token cannot be zero address");
        require(_feeReceiver != address(0), "feeReceiver cannot be zero address");
        require(_lisUSD != address(0), "lisUSD cannot be zero address");
        require(_sellFee <= FEE_PRECISION, "sellFee must be less or equal than FEE_PRECISION");
        require(_buyFee <= FEE_PRECISION, "buyFee must be less or equal than FEE_PRECISION");
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER, msg.sender);

        token = _token;
        sellFee = _sellFee;
        buyFee = _buyFee;
        feeReceiver = _feeReceiver;
        lisUSD = _lisUSD;

        sellLimit = _sellLimit;
        buyLimit = _buyLimit;
        dailyLimit = _dailyLimit;
        minSell = _minSell;
        minBuy = _minBuy;

        emit SetBuyFee(_buyFee);
        emit SetSellFee(_sellFee);
        emit SetFeeReceiver(_feeReceiver);
        emit SetSellLimit(_sellLimit);
        emit SetBuyLimit(_buyLimit);
        emit SetDailyLimit(_dailyLimit);
        emit SetMinSell(_minSell);
        emit SetMinBuy(_minBuy);
    }

    /**
     * @dev sell token to get lisUSD
     * @param amount token amount
     */
    function sell(uint256 amount) external nonReentrant whenNotPaused {
        // check sell limit
        checkAndUpdateSellUsed(amount);

        // transfer token from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // calculate fee and real amount
        uint256 fee = Math.mulDiv(amount, sellFee, FEE_PRECISION);
        uint256 realAmount = amount - fee;

        // mint lisUSD to user
        HayLike(lisUSD).mint(msg.sender, realAmount);

        // deposit token to vault manager
        IERC20(token).safeIncreaseAllowance(vaultManager, amount);
        IVaultManager(vaultManager).deposit(amount);

        // mint fee to fee receiver
        if (fee > 0) {
            HayLike(lisUSD).mint(feeReceiver, fee);
        }
        emit Selltoken(msg.sender, realAmount, fee);
    }

    /**
     * @dev buy token with lisUSD
     * @param amount lisUSD amount
     */
    function buy(uint256 amount) external nonReentrant whenNotPaused {
        // check buy limit
        checkAndUpdateBuyUsed(amount);

        // calculate fee and real amount
        uint256 fee = Math.mulDiv(amount, buyFee, FEE_PRECISION);
        uint256 realAmount = amount - fee;

        // burn lisUSD from user and withdraw token from vault manager
        if (realAmount > 0) {
            HayLike(lisUSD).burn(msg.sender, realAmount);
            IVaultManager(vaultManager).withdraw(msg.sender, realAmount);
        }

        // transfer fee to fee receiver
        if (fee > 0) {
            IERC20(lisUSD).safeTransferFrom(msg.sender, feeReceiver, fee);
        }
        emit Buytoken(msg.sender, realAmount, fee);
    }

    // check sell limit
    function checkSellLimit(uint256 amount) public view returns (bool) {
        // check min sell amount
        if (amount < minSell) {
            return false;
        }

        // check total sell limit
        if (amount + totalSellUsed > sellLimit) {
            return false;
        }

        return true;
    }

    // check and update sell used
    function checkAndUpdateSellUsed(uint256 amount) private {
        require(checkSellLimit(amount), "exceed sell limit");
        // update total sell used
        totalSellUsed += amount;
    }

    // check buy limit
    function checkBuyLimit(uint256 amount) public view returns (bool) {
        // check min buy amount
        if (amount < minBuy) {
            return false;
        }
        // check total buy limit
        if (amount + totalBuyUsed > buyLimit) {
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
        require(checkBuyLimit(amount), "exceed buy limit");

        // update total buy used
        if (getDay() != lastBuyDay) {
            lastBuyDay = getDay();
            dayBuyUsed = 0;
        }

        dayBuyUsed += amount;
        totalBuyUsed += amount;
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
     * @dev set sell limit
     * @param _sellLimit sell limit
     */
    function setSellLimit(uint256 _sellLimit) external onlyRole(MANAGER) {
        sellLimit = _sellLimit;
        emit SetSellLimit(_sellLimit);
    }

    /**
     * @dev set buy limit
     * @param _buyLimit buy limit
     */
    function setBuyLimit(uint256 _buyLimit) external onlyRole(MANAGER) {
        buyLimit = _buyLimit;
        emit SetBuyLimit(_buyLimit);
    }

    /**
     * @dev set daily limit
     * @param _dailyLimit daily limit
     */
    function setDailyLimit(uint256 _dailyLimit) external onlyRole(MANAGER) {
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
        minBuy = _minBuy;
        emit SetMinBuy(_minBuy);
    }

    /**
     * @dev pause contract
     */
    function pause() external onlyRole(PAUSE) {
        _pause();
    }

    /**
     * @dev toggle pause contract
     */
    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }
}