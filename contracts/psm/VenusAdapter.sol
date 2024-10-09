pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IVBep20Delegate.sol";

contract VenusAdapter is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    address public vaultManager; // vault manager address
    address public venusPool; // venus pool address
    address public gem; // gem address
    address public vToken; // vToken address

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
     * @param _gem gem address
     * @param _vToken vToken address
     */
    function initialize(address _vaultManager, address _venusPool, address _gem, address _vToken) public initializer {
        __Ownable_init();
        require(_vaultManager != address(0), "vaultManager cannot be zero address");
        require(_venusPool != address(0), "venusPool cannot be zero address");
        require(_gem != address(0), "gem cannot be zero address");
        require(_vToken != address(0), "vToken cannot be zero address");

        vaultManager = _vaultManager;
        gem = _gem;
        venusPool = _venusPool;
        vToken = _vToken;
    }

    /**
     * @dev deposit gem by vault manager
     * @param amount deposit amount
     */
    function deposit(uint256 amount) external onlyVaultManager {
        require(amount > 0, "deposit amount cannot be zero");
        IERC20(gem).safeTransferFrom(vaultManager, address(this), amount);
        IERC20(gem).safeIncreaseAllowance(venusPool, amount);

        // deposit to venus pool
        IVBep20Delegate(venusPool).mint(amount);

        emit Deposit(amount);
    }

    /**
     * @dev withdraw gem by vault manager
     * @param account withdraw account
     * @param amount withdraw amount
     */
    function withdraw(address account, uint256 amount) external onlyVaultManager {
        require(amount > 0, "withdraw amount cannot be zero");
        // calculate vToken amount
        uint256 vTokenAmount = Math.mulDiv(amount, 1e18, IVBep20Delegate(venusPool).exchangeRateStored());

        if (vTokenAmount == 0) {
            return;
        }
        // withdraw from venus pool
        IERC20(vToken).safeIncreaseAllowance(venusPool, vTokenAmount);
        uint256 before = IERC20(gem).balanceOf(address(this));
        IVBep20Delegate(venusPool).redeem(vTokenAmount);
        uint256 gemAmount = IERC20(gem).balanceOf(address(this)) - before;

        // transfer gem to account
        IERC20(gem).safeTransfer(account, gemAmount);

        emit Withdraw(account, gemAmount);
    }

    /**
     * @dev get total available amount
     */
    function totalAvailableAmount() public view returns (uint256) {
        uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));
        uint256 gemAmount = Math.mulDiv(vTokenAmount, IVBep20Delegate(venusPool).exchangeRateStored(), 1e18);
        return gemAmount;
    }

    /**
     * @dev withdraw all gem to vault manager
     */
    function withdrawAll() external onlyVaultManager returns (uint256) {
        uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));
        if (vTokenAmount > 0) {
            uint256 before = IERC20(gem).balanceOf(address(this));
            IVBep20Delegate(venusPool).redeem(vTokenAmount);
            uint256 gemAmount = IERC20(gem).balanceOf(address(this)) - before;

            IERC20(gem).safeTransfer(vaultManager, gemAmount);
            return gemAmount;
        }
        return 0;
    }
}