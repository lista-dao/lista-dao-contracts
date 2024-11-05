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
    address public venusPool; // venus pool address
    address public token; // token address
    address public vToken; // vToken address
    uint256 public netDepositAmount; // user net deposit amount
    address public feeReceiver; // fee receiver address

    uint256 public deltaAmount; // delta amount
    uint256 public delta; // delta

    bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role

    event Deposit(uint256 amount);
    event Withdraw(address account, uint256 amount);
    event Harvest(address account, uint256 amount);
    event SetFeeReceiver(address feeReceiver);

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
     * @param _venusPool venus pool address
     * @param _token token address
     * @param _vToken vToken address
     * @param _deltaAmount delta amount
     * @param _feeReceiver fee receiver address
     */
    function initialize(
            address _admin,
            address _manager,
            address _vaultManager, 
            address _venusPool, 
            address _token, 
            address _vToken,
            uint256 _deltaAmount,
            address _feeReceiver
        ) public initializer {
        require(_admin != address(0), "admin cannot be zero address");
        require(_manager != address(0), "manager cannot be zero address");
        require(_vaultManager != address(0), "vaultManager cannot be zero address");
        require(_venusPool != address(0), "venusPool cannot be zero address");
        require(_token != address(0), "token cannot be zero address");
        require(_vToken != address(0), "vToken cannot be zero address");
        require(_feeReceiver != address(0), "feeReceiver cannot be zero address");

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MANAGER, _manager);

        vaultManager = _vaultManager;
        token = _token;
        venusPool = _venusPool;
        vToken = _vToken;
        deltaAmount = _deltaAmount;
    }

    /**
     * @dev deposit token by vault manager
     * @param amount deposit amount
     */
    function deposit(uint256 amount) external onlyVaultManager {
        require(amount > 0, "deposit amount cannot be zero");
        IERC20(token).safeTransferFrom(vaultManager, address(this), amount);
        IERC20(token).safeIncreaseAllowance(venusPool, amount);

        netDepositAmount += amount;

        // deposit to venus pool
        IVBep20Delegate(venusPool).mint(amount);

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

        // withdraw amount contains delta amount
        uint256 withdrawAmount = amount + deltaAmount - delta;

        uint256 exchangeRate = IVBep20Delegate(venusPool).exchangeRateStored();
        // calculate vToken amount
        uint256 vTokenAmount = Math.mulDiv(withdrawAmount, 1e18, exchangeRate);

        require(vTokenAmount > 0, "no vToken to withdraw");
        require(IERC20(vToken).balanceOf(address(this)) >= vTokenAmount, "not enough vToken");

        // withdraw from venus pool
        uint256 tokenAmount = _withdrawFromVenus(vTokenAmount);

        require(tokenAmount + delta >= amount, "not enough token");

        delta = tokenAmount + delta - amount;

        // transfer token to account
        IERC20(token).safeTransfer(account, amount);

        emit Withdraw(account, tokenAmount);
    }

    /**
     * @dev get total available amount
     */
    function totalAvailableAmount() public view returns (uint256) {
        uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));
        uint256 tokenAmount = Math.mulDiv(vTokenAmount, IVBep20Delegate(venusPool).exchangeRateStored(), 1e18);
        return tokenAmount;
    }

    /**
     * @dev withdraw all token to vault manager
     */
    function withdrawAll() external onlyVaultManager returns (uint256) {
        // harvest interest to fee receiver
        harvest();

        // withdraw all token to vault manager
        netDepositAmount = 0;

        uint256 totalAmount = delta;
        uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));

        if (vTokenAmount > 0) {
            totalAmount += _withdrawFromVenus(vTokenAmount);
        }
        IERC20(token).safeTransfer(vaultManager, totalAmount);
        return totalAmount;
    }

    /**
     * @dev set delta amount
     * @param _deltaAmount delta amount
     */
    function setDeltaAmount(uint256 _deltaAmount) external onlyRole(MANAGER) {
        deltaAmount = _deltaAmount;
    }

    /**
     * @dev harvest interest to fee receiver
     */
    function harvest() public {
        uint256 totalAmount = totalAvailableAmount() + delta;
        if (totalAmount > netDepositAmount) {
            // calculate interest and redeem amount
            uint256 interest = totalAmount - netDepositAmount;
            uint256 exchangeRate = IVBep20Delegate(venusPool).exchangeRateStored();
            uint256 interestVTokenAmount = Math.mulDiv(interest, 1e18, exchangeRate);

            if (interestVTokenAmount > 0) {
                // redeem interest
                uint256 fee = _withdrawFromVenus(interestVTokenAmount);

                if (fee > 0) {
                    // transfer fee to fee receiver
                    IERC20(token).safeTransfer(feeReceiver, fee);

                    emit Harvest(feeReceiver, fee);
                }
            }
        }
    }

    function _withdrawFromVenus(uint256 vTokenAmount) private returns (uint256) {
        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(vToken).safeIncreaseAllowance(venusPool, vTokenAmount);
        IVBep20Delegate(venusPool).redeem(vTokenAmount);
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