pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/HayLike.sol";

contract PSM is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    address public vaultManager;
    address public gem;
    uint256 public sellFee;
    uint256 public buyFee;
    address public feeReceiver;
    address public lisUSD;

    uint256 public sellLimit;
    uint256 public buyLimit;
    uint256 public dailyLimit;
    uint256 public minSell;
    uint256 public minBuy;

    uint256 public lastBuyDay;
    uint256 public dayBuyUsed;
    uint256 public totalBuyUsed;
    uint256 public totalSellUsed;

    uint256 public constant FEE_PRECISION = 10000;

    event SetBuyFee(uint256 buyFee);
    event SetSellFee(uint256 sellFee);
    event SetFeeReceiver(address feeReceiver);
    event BuyGem(address account, uint256 realAmount, uint256 fee);
    event SellGem(address account, uint256 realAmount, uint256 fee);
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
       * @param _gem gem address
       * @param _sellFee sell fee
       * @param _buyFee buy fee
       * @param _feeReceiver fee receiver address
       * @param _lisUSD lisUSD address
      */
    function initialize(
        address _gem,
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
        require(_gem != address(0), "gem cannot be zero address");
        require(_feeReceiver != address(0), "feeReceiver cannot be zero address");
        require(_lisUSD != address(0), "lisUSD cannot be zero address");
        require(_sellFee <= FEE_PRECISION, "sellFee must be less or equal than FEE_PRECISION");
        require(_buyFee <= FEE_PRECISION, "buyFee must be less or equal than FEE_PRECISION");
        __Ownable_init();

        gem = _gem;
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

    function sellGem(uint256 amount) external nonReentrant {
        checkAndUpdateSellUsed(amount);

        IERC20(gem).safeTransferFrom(msg.sender, address(this), amount);

        // calculate fee
        uint256 fee = Math.mulDiv(amount, sellFee, FEE_PRECISION);
        uint256 realAmount = amount - fee;

        // mint lisUSD, then transfer to user
        HayLike(lisUSD).mint(address(this), amount);
        IERC20(lisUSD).safeTransfer(msg.sender, realAmount);

        // deposit gem to vault manager
        IERC20(gem).safeIncreaseAllowance(vaultManager, amount);
        IVaultManager(vaultManager).deposit(amount);

        if (fee > 0) {
            IERC20(lisUSD).safeTransfer(feeReceiver, fee);
        }
        emit SellGem(msg.sender, realAmount, fee);
    }

    function buyGem(uint256 amount) external nonReentrant {
        checkAndUpdateBuyUsed(amount);

        // calculate fee
        uint256 fee = Math.mulDiv(amount, buyFee, FEE_PRECISION);
        uint256 realAmount = amount - fee;

        if (realAmount > 0) {
            HayLike(lisUSD).burn(msg.sender, realAmount);
            IVaultManager(vaultManager).withdraw(msg.sender, realAmount);
        }

        if (fee > 0) {
            IERC20(lisUSD).safeTransferFrom(msg.sender, feeReceiver, fee);
        }
        emit BuyGem(msg.sender, realAmount, fee);
    }

    function checkSellLimit(uint256 amount) public view returns (bool) {
        if (amount < minSell) {
            return false;
        }

        if (amount + totalSellUsed > sellLimit) {
            return false;
        }

        return true;
    }

    function checkAndUpdateSellUsed(uint256 amount) private {
        require(checkSellLimit(amount), "exceed sell limit");
        totalSellUsed += amount;
    }

    function checkBuyLimit(uint256 amount) public view returns (bool) {
        if (amount < minBuy) {
            return false;
        }
        if (amount > dailyLimit) {
            return false;
        }
        if (amount + totalBuyUsed > buyLimit) {
            return false;
        }
        if (getDay() == lastBuyDay && dayBuyUsed + amount > dailyLimit) {
            return false;
        }
        return true;
    }

    function checkAndUpdateBuyUsed(uint256 amount) private {
        require(checkBuyLimit(amount), "exceed buy limit");

        if (getDay() != lastBuyDay) {
            lastBuyDay = getDay();
            dayBuyUsed = 0;
        }

        dayBuyUsed += amount;
        totalBuyUsed += amount;
    }

    function getDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function setVaultManager(address _vaultManager) external onlyOwner {
        require(_vaultManager != address(0), "VaultManager cannot be zero address");
        vaultManager = _vaultManager;
        emit SetVaultManager(_vaultManager);
    }

    function setBuyFee(uint256 _buyFee) external onlyOwner {
        require(_buyFee <= FEE_PRECISION, "buyFee must be less or equal than FEE_PRECISION");
        buyFee = _buyFee;
        emit SetBuyFee(_buyFee);
    }

    function setSellFee(uint256 _sellFee) external onlyOwner {
        require(_sellFee <= FEE_PRECISION, "sellFee must be less or equal than FEE_PRECISION");
        sellFee = _sellFee;
        emit SetSellFee(_sellFee);
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0), "feeReceiver cannot be zero address");
        feeReceiver = _feeReceiver;
        emit SetFeeReceiver(_feeReceiver);
    }

    function setSellLimit(uint256 _sellLimit) external onlyOwner {
        sellLimit = _sellLimit;
        emit SetSellLimit(_sellLimit);
    }

    function setBuyLimit(uint256 _buyLimit) external onlyOwner {
        buyLimit = _buyLimit;
        emit SetBuyLimit(_buyLimit);
    }

    function setDailyLimit(uint256 _dailyLimit) external onlyOwner {
        dailyLimit = _dailyLimit;
        emit SetDailyLimit(_dailyLimit);
    }

    function setMinSell(uint256 _minSell) external onlyOwner {
        minSell = _minSell;
        emit SetMinSell(_minSell);
    }

    function setMinBuy(uint256 _minBuy) external onlyOwner {
        minBuy = _minBuy;
        emit SetMinBuy(_minBuy);
    }
}