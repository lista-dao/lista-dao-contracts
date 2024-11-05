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
    uint256 public delta; // delta

    uint256 public deltaAmount; // delta amount

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
     * @param _admin admin address
     * @param _manager manager address
     * @param _vaultManager vault manager address
     * @param _venusPool venus pool address
     * @param _token token address
     * @param _vToken vToken address
     */
    function initialize(
            address _admin,
            address _manager,
            address _vaultManager, 
            address _venusPool, 
            address _token, 
            address _vToken,
            uint256 _deltaAmount
        ) public initializer {
        require(_admin != address(0), "admin cannot be zero address");
        require(_manager != address(0), "manager cannot be zero address");
        require(_vaultManager != address(0), "vaultManager cannot be zero address");
        require(_venusPool != address(0), "venusPool cannot be zero address");
        require(_token != address(0), "token cannot be zero address");
        require(_vToken != address(0), "vToken cannot be zero address");

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

        // withdraw from delta
        require(vTokenAmount > 0, "no vToken to withdraw");
        // withdraw from venus pool
        IERC20(vToken).safeIncreaseAllowance(venusPool, vTokenAmount);
        uint256 before = IERC20(token).balanceOf(address(this));
        IVBep20Delegate(venusPool).redeem(vTokenAmount);
        uint256 tokenAmount = IERC20(token).balanceOf(address(this)) - before;

        uint256 remain = amount - tokenAmount;
        if (remain > 0) {
            if (delta < remain) {
                _withdrawDelta();
                require(delta >= remain, "not enough delta");
            }
            delta -= remain;
        }

        // transfer token to account
        IERC20(token).safeTransfer(account, amount);

        emit Withdraw(account, tokenAmount);
    }

    // withdraw delta from venus pool
    function _withdrawDelta() private {
        uint256 vTokenAmount = Math.mulDiv(deltaAmount, 1e18, IVBep20Delegate(venusPool).exchangeRateStored());
        require(IERC20(vToken).balanceOf(address(this)) >= vTokenAmount, "not enough vToken");
        IERC20(vToken).safeIncreaseAllowance(venusPool, vTokenAmount);
        uint256 before = IERC20(token).balanceOf(address(this));
        IVBep20Delegate(venusPool).redeem(vTokenAmount);
        uint256 tokenAmount = IERC20(token).balanceOf(address(this)) - before;
        delta += tokenAmount;
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
        uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));

        uint256 tokenAmount = delta;
        delta = 0;
        if (vTokenAmount > 0) {
            uint256 before = IERC20(token).balanceOf(address(this));
            IVBep20Delegate(venusPool).redeem(vTokenAmount);
            tokenAmount += IERC20(token).balanceOf(address(this)) - before;

        }
        IERC20(token).safeTransfer(vaultManager, tokenAmount);
        return tokenAmount;
    }

    /**
     * @dev set delta amount
     * @param _deltaAmount delta amount
     */
    function setDeltaAmount(uint256 _deltaAmount) external onlyRole(MANAGER) {
        deltaAmount = _deltaAmount;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}