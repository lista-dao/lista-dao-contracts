pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IVBep20Delegate.sol";

contract ListaAdapter is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    address public gem; // gem address
    address public vaultManager; // vault manager address

    uint256 public totalAvailableAmount; // total available amount
    uint256 public operatorWithdraw; // operator withdraw amount

    mapping(address => bool) public operators; // operator address -> status

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
    modifier onlyOperator() {
        require(operators[msg.sender], "only operator can call this function");
        _;
    }

    /**
     * @dev initialize contract
     * @param _gem gem address
     * @param _vaultManager vault manager address
     */
    function initialize(address _gem, address _vaultManager) public initializer {
        __Ownable_init();
        require(_vaultManager != address(0), "vaultManager cannot be zero address");
        require(_gem != address(0), "gem cannot be zero address");

        gem = _gem;
        vaultManager = _vaultManager;
    }

    /**
     * @dev deposit gem by vault manager
     * @param amount deposit amount
     */
    function deposit(uint256 amount) external onlyVaultManager {
        require(amount > 0, "deposit amount cannot be zero");
        // transfer gem from vault manager to this contract
        IERC20(gem).safeTransferFrom(msg.sender, address(this), amount);
        totalAvailableAmount += amount;

        emit Deposit(amount);
    }

    /**
     * @dev withdraw gem by vault manager
     * @param account account address
     * @param amount deposit amount
     */
    function withdraw(address account, uint256 amount) external onlyVaultManager {
        require(amount > 0, "withdraw amount cannot be zero");
        require(totalAvailableAmount >= amount, "insufficient balance");

        // withdraw from total available amount
        totalAvailableAmount -= amount;
        IERC20(gem).safeTransfer(account, amount);

        emit Withdraw(account, amount);
    }

    /**
     * @dev withdraw gem by operator
     * @param amount withdraw amount
     */
    function withdrawByOperator(uint256 amount) external onlyOperator {
        require(amount > 0, "withdraw amount cannot be zero");
        require(totalAvailableAmount >= amount, "insufficient balance");

        // withdraw from total available amount and add to operator withdraw
        totalAvailableAmount -= amount;
        operatorWithdraw += amount;

        IERC20(gem).safeTransfer(msg.sender, amount);

        emit OperatorWithdraw(msg.sender, amount);
    }

    /**
     * @dev deposit gem by operator
     * @param amount deposit amount
     */
    function depositByOperator(uint256 amount) external onlyOperator {
        require(amount > 0, "deposit amount cannot be zero");
        IERC20(gem).safeTransferFrom(msg.sender, address(this), amount);

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
     * @dev set operator
     * @param _operator operator address
     */
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "operator cannot be zero address");
        operators[_operator] = true;

        emit AddOperator(_operator);
    }

    /**
     * @dev remove operator
     * @param _operator operator address
     */
    function removeOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "operator cannot be zero address");
        operators[_operator] = false;

        emit RemoveOperator(_operator);
    }

    /**
     * @dev withdraw all gem to vault manager
     */
    function withdrawAll() external onlyVaultManager returns (uint256) {
        if (totalAvailableAmount > 0) {
            uint256 amount = totalAvailableAmount;
            totalAvailableAmount = 0;
            IERC20(gem).safeTransfer(vaultManager, amount);
            return amount;
        }
        return 0;
    }

}