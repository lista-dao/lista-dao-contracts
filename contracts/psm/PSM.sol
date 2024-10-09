pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IEarnPool.sol";
import "../interfaces/HayLike.sol";

contract PSM is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    address public earnPool;
    address public gem;
    uint256 public sellFee;
    uint256 public buyFee;
    address public feeReceiver;
    address public lisUSD;
    address public jar;

    uint256 public constant FEE_PRECISION = 10000;

    event SetEarnPool(address earnPool);
    event SetBuyFee(uint256 buyFee);
    event SetSellFee(uint256 sellFee);
    event SetFeeReceiver(address feeReceiver);
    event DepositGem(address account, uint256 realAmount, uint256 fee);

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
    function initialize(address _gem, uint256 _sellFee, uint256 _buyFee, address _feeReceiver, address _lisUSD) public initializer {
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

        emit SetBuyFee(_buyFee);
        emit SetSellFee(_sellFee);
        emit SetFeeReceiver(_feeReceiver);
    }

    function depositGem(uint256 amount) external nonReentrant {
        require(amount > 0, "amount is zero");
        IERC20(gem).safeTransferFrom(msg.sender, address(this), amount);

        // calculate fee
        uint256 fee = Math.mulDiv(amount, sellFee, FEE_PRECISION);
        uint256 realAmount = amount - fee;

        // mint lisUSD, then deposit gem and lisUSD to earn pool
        HayLike(lisUSD).mint(address(this), amount);
        IERC20(gem).safeIncreaseAllowance(earnPool, amount);
        IERC20(lisUSD).safeIncreaseAllowance(earnPool, realAmount);
        IEarnPool(earnPool).deposit(msg.sender, amount, realAmount);

        if (fee > 0) {
            IERC20(lisUSD).safeTransfer(feeReceiver, fee);
        }
        emit DepositGem(msg.sender, realAmount, fee);
    }

    function withdrawLisUSD() external nonReentrant {
        IEarnPool(earnPool).withdrawLisUSD(msg.sender);
    }

    function withdrawGem() external nonReentrant {
        uint256 lisUSDAmount = IEarnPool(earnPool).withdrawLisUSD(msg.sender);
        require(lisUSDAmount > 0, "lisUSDAmount is zero");
        // calculate fee
        uint256 fee = Math.mulDiv(lisUSDAmount, buyFee, FEE_PRECISION);
        uint256 realAmount = lisUSDAmount - fee;

        if (realAmount > 0) {
            // withdraw gem and burn lisUSD
            IEarnPool(earnPool).withdrawGem(msg.sender, realAmount);
            HayLike(lisUSD).burn(address(this), realAmount);
        }

        if (fee > 0) {
            IERC20(lisUSD).safeTransfer(feeReceiver, fee);
        }
    }

    function buyGem(uint256 amount) external nonReentrant {
        require(amount > 0, "amount is zero");

        // calculate fee
        uint256 fee = Math.mulDiv(amount, buyFee, FEE_PRECISION);
        uint256 realAmount = amount + fee;

        HayLike(lisUSD).burn(msg.sender, realAmount);
        IEarnPool(earnPool).withdrawGem(msg.sender, amount);

        if (fee > 0) {
            IERC20(lisUSD).safeTransfer(feeReceiver, fee);
        }
    }

    function setEarnPool(address _earnPool) external onlyOwner {
        require(_earnPool != address(0), "earnPool cannot be zero address");
        earnPool = _earnPool;
        emit SetEarnPool(_earnPool);
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
}