pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interfaces/IVBep20Delegate.sol";

contract ListaAdapter is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    address public token; // token address
    address public vaultManager; // vault manager address

    uint256 public totalAvailableAmount; // total available amount
    uint256 public operatorWithdraw; // operator withdraw amount

    bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role

    event Deposit(uint256 amount);
    event Withdraw(address account, uint256 amount);
    event OperatorDeposit(address account, uint256 amount);
    event OperatorWithdraw(address account, uint256 amount);
    event AddOperator(address operator);
    event RemoveOperator(address operator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyVaultManager() {
        require(msg.sender == vaultManager, "only vaultManager can call this function");
        _;
    }

    /**
     * @dev initialize contract
     * @param _token token address
     * @param _vaultManager vault manager address
     */
    function initialize(address _token, address _vaultManager) public initializer {
        require(_vaultManager != address(0), "vaultManager cannot be zero address");
        require(_token != address(0), "token cannot be zero address");
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER, msg.sender);

        token = _token;
        vaultManager = _vaultManager;
    }

    /**
     * @dev deposit token by vault manager
     * @param amount deposit amount
     */
    function deposit(uint256 amount) external onlyVaultManager {
        require(amount > 0, "deposit amount cannot be zero");
        // transfer token from vault manager to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        totalAvailableAmount += amount;

        emit Deposit(amount);
    }

    /**
     * @dev withdraw token by vault manager
     * @param account account address
     * @param amount deposit amount
     */
    function withdraw(address account, uint256 amount) external onlyVaultManager {
        require(amount > 0, "withdraw amount cannot be zero");
        require(totalAvailableAmount >= amount, "insufficient balance");

        // withdraw from total available amount
        totalAvailableAmount -= amount;
        IERC20(token).safeTransfer(account, amount);

        emit Withdraw(account, amount);
    }

    /**
     * @dev withdraw token by operator
     * @param amount withdraw amount
     */
    function withdrawByOperator(uint256 amount) external onlyRole(MANAGER) {
        require(amount > 0, "withdraw amount cannot be zero");
        require(totalAvailableAmount >= amount, "insufficient balance");

        // withdraw from total available amount and add to operator withdraw
        totalAvailableAmount -= amount;
        operatorWithdraw += amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit OperatorWithdraw(msg.sender, amount);
    }

    /**
     * @dev deposit token by operator
     * @param amount deposit amount
     */
    function depositByOperator(uint256 amount) external onlyRole(MANAGER) {
        require(amount > 0, "deposit amount cannot be zero");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // add operatorWithdraw to total available amount
        totalAvailableAmount += amount;
        if(amount >= operatorWithdraw) {
            operatorWithdraw = 0;
        } else {
            operatorWithdraw -= amount;
        }

        emit OperatorDeposit(msg.sender, amount);
    }

    /**
     * @dev withdraw all token to vault manager
     */
    function withdrawAll() external onlyVaultManager returns (uint256) {
        if (totalAvailableAmount > 0) {
            uint256 amount = totalAvailableAmount;
            totalAvailableAmount = 0;
            IERC20(token).safeTransfer(vaultManager, amount);
            return amount;
        }
        return 0;
    }

}