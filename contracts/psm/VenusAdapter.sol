pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IVBep20Delegate.sol";

contract VenusAdapter is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    address public vaultManager; // vault manager address
    address public venusPool; // venus pool address
    address public token; // token address
    address public vToken; // vToken address
    uint256 public quota; // quota

    uint256 public quotaAmount; // quota amount

    bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role

    event Deposit(uint256 amount);
    event Withdraw(address account, uint256 amount);

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
     * @param _vaultManager vault manager address
     * @param _venusPool venus pool address
     * @param _token token address
     * @param _vToken vToken address
     */
    function initialize(
            address _vaultManager, 
            address _venusPool, 
            address _token, 
            address _vToken,
            uint256 _quotaAmount
        ) public initializer {
        require(_vaultManager != address(0), "vaultManager cannot be zero address");
        require(_venusPool != address(0), "venusPool cannot be zero address");
        require(_token != address(0), "token cannot be zero address");
        require(_vToken != address(0), "vToken cannot be zero address");

        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER, msg.sender);

        vaultManager = _vaultManager;
        token = _token;
        venusPool = _venusPool;
        vToken = _vToken;
        quotaAmount = _quotaAmount;
    }

    /**
     * @dev deposit token by vault manager
     * @param amount deposit amount
     */
    function deposit(uint256 amount) external onlyVaultManager {
        require(amount > 0, "deposit amount cannot be zero");
        IERC20(token).safeTransferFrom(vaultManager, address(this), amount);
        IERC20(token).safeIncreaseAllowance(venusPool, amount);

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

        uint256 exchangeRate = IVBep20Delegate(venusPool).exchangeRateStored();
        // calculate vToken amount
        uint256 vTokenAmount = Math.mulDiv(amount, 1e18, exchangeRate);
        require(IERC20(vToken).balanceOf(address(this)) >= vTokenAmount, "not enough vToken");

        // withdraw from quota
        if (vTokenAmount == 0) {
            if (quota < amount) {
                _withdrawQuota();
                require(quota >= amount, "not enough quota");
            }
            quota -= amount;
            IERC20(token).safeTransfer(account, amount);
            emit Withdraw(account, amount);
            return;
        }
        // withdraw from venus pool
        IERC20(vToken).safeIncreaseAllowance(venusPool, vTokenAmount);
        uint256 before = IERC20(token).balanceOf(address(this));
        IVBep20Delegate(venusPool).redeem(vTokenAmount);
        uint256 tokenAmount = IERC20(token).balanceOf(address(this)) - before;

        uint256 remain = amount - tokenAmount;
        if (remain > 0) {
            if (quota < remain) {
                _withdrawQuota();
                require(quota >= remain, "not enough quota");
            }
            quota -= remain;
        }

        // transfer token to account
        IERC20(token).safeTransfer(account, amount);

        emit Withdraw(account, tokenAmount);
    }

    // withdraw quota from venus pool
    function _withdrawQuota() private {
        uint256 vTokenAmount = Math.mulDiv(quotaAmount, 1e18, IVBep20Delegate(venusPool).exchangeRateStored());
        require(IERC20(vToken).balanceOf(address(this)) >= vTokenAmount, "not enough vToken");
        IERC20(vToken).safeIncreaseAllowance(venusPool, vTokenAmount);
        uint256 before = IERC20(token).balanceOf(address(this));
        IVBep20Delegate(venusPool).redeem(vTokenAmount);
        uint256 tokenAmount = IERC20(token).balanceOf(address(this)) - before;
        quota += tokenAmount;
    }

    /**
     * @dev get total available amount
     */
    function totalAvailableAmount() public view returns (uint256) {
        uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));
        uint256 tokenAmount = Math.mulDiv(vTokenAmount, IVBep20Delegate(venusPool).exchangeRateStored(), 1e18)
            + quota;
        return tokenAmount;
    }

    /**
     * @dev withdraw all token to vault manager
     */
    function withdrawAll() external onlyVaultManager returns (uint256) {
        uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));
        uint256 tokenAmount = quota;
        if (vTokenAmount > 0) {
            uint256 before = IERC20(token).balanceOf(address(this));
            IVBep20Delegate(venusPool).redeem(vTokenAmount);
            tokenAmount += IERC20(token).balanceOf(address(this)) - before;

        }
        IERC20(token).safeTransfer(vaultManager, tokenAmount);
        return tokenAmount;
    }

    /**
     * @dev set quota amount
     * @param _quotaAmount quota amount
     */
    function setQuotaAmount(uint256 _quotaAmount) external onlyRole(MANAGER) {
        quotaAmount = _quotaAmount;
    }
}