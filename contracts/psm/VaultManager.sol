pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IAdapter.sol";

contract VaultManager is AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    address public psm; // PSM address
    address public token; // token address

    struct Adapter {
        address adapter; // adapter address
        bool active; // active status
        uint256 point; // adapter point
    }

    Adapter[] public adapters; // adapter list
    uint256 public localToken; // local token amount
    uint256 public netDepositAmount; // net deposit amount
    address public feeReceiver; // fee receiver address

    uint256 constant public MAX_PRECISION = 10000;
    bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
    bytes32 public constant BOT = keccak256("BOT"); // bot role

    event SetPSM(address psm);
    event SetToken(address token);
    event SetAdapter(address adapter, bool active, uint256 point);
    event SetFeeReceiver(address feeReceiver);
    event AddAdapter(address adapter, uint256 point);
    event Deposit(uint256 amount);
    event Withdraw(address receiver, uint256 amount);
    event ReBalance(uint256 amount);
    event EmergencyWithdraw(address account, uint256 amount);
    event Harvest(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
      * @dev initialize contract
      * @param _admin admin address
      * @param _manager manager address
      * @param _psm PSM address
      * @param _token token address
      * @param _feeReceiver fee receiver address
      */
    function initialize(
        address _admin,
        address _manager,
        address _psm,
        address _token,
        address _feeReceiver
    ) public initializer {
        require(_admin != address(0), "admin cannot be zero address");
        require(_manager != address(0), "manager cannot be zero address");
        require(_psm != address(0), "psm cannot be zero address");
        require(_token != address(0), "token cannot be zero address");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MANAGER, _manager);

        psm = _psm;
        token = _token;
        feeReceiver = _feeReceiver;

        emit SetPSM(_psm);
        emit SetToken(_token);
        emit SetFeeReceiver(_feeReceiver);
    }

    modifier onlyPSM() {
        require(msg.sender == psm, "Only PSM can call this function");
        _;
    }

    modifier onlyPSMOrManager() {
        require(msg.sender == psm || hasRole(MANAGER, msg.sender), "Only PSM or Manager can call this function");
        _;
    }

    /**
      * @dev deposit token to adapters, only PSM can call this function
      * @param amount deposit amount
      */
    function deposit(uint256 amount) external onlyPSMOrManager {
        require(amount > 0, "deposit amount cannot be zero");

        // transfer token to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _distribute(amount);

        netDepositAmount += amount;
        emit Deposit(amount);
    }

    function _distribute(uint256 amount) private {
        uint256 remain = amount;
        uint256 totalPoint = getTotalPoint();

        // deposit token to adapters by adapter point
        for (uint256 i = 0; i < adapters.length; i++) {
            if (adapters[i].active) { // only active adapter can be used
                //  adapterAmount = depositAmount * point / totalPoint
                uint256 amt = Math.mulDiv(amount, adapters[i].point, totalPoint);
                if (amt > 0) {
                    IERC20(token).safeIncreaseAllowance(adapters[i].adapter, amt);
                    IAdapter(adapters[i].adapter).deposit(amt);
                    remain -= amt;
                }
            }
        }

        // if remain amount > 0, add to local token
        if (remain > 0) {
            localToken += remain;
        }
    }

    function getTotalPoint() public view returns (uint256) {
        uint256 totalPoint;
        for (uint256 i = 0; i < adapters.length; i++) {
            if (adapters[i].active) {
                totalPoint += adapters[i].point;
            }
        }

        return totalPoint;
    }

    /**
      * @dev withdraw token from adapters, only PSM can call this function
      * @param receiver receiver address
      * @param amount withdraw amount
      */
    function withdraw(address receiver, uint256 amount) external onlyPSM {
        require(amount > 0, "withdraw amount cannot be zero");

        require(amount <= netDepositAmount, "withdraw amount exceeds net deposit amount");

        netDepositAmount -= amount;

        uint256 remain = amount;

        // withdraw token from local first
        if (localToken >= remain) {
            IERC20(token).safeTransfer(receiver, remain);
            localToken -= remain;
            return;
        } else {
            IERC20(token).safeTransfer(receiver, localToken);
            remain -= localToken;
            localToken = 0;
        }

        // withdraw token from adapters
        for (uint256 i = 0; i < adapters.length; i++) {
            uint256 totalAvailableAmount = IAdapter(adapters[i].adapter).totalAvailableAmount();
            if (totalAvailableAmount >= remain) {
                IAdapter(adapters[i].adapter).withdraw(receiver, remain);
                return;
            } else {
                IAdapter(adapters[i].adapter).withdraw(receiver, totalAvailableAmount);
                remain -= totalAvailableAmount;
            }
        }

        require(remain == 0, "not enough available balance");

        emit Withdraw(receiver, amount);
    }

    /**
      * @dev add adapter
      * @param adapter adapter address
      * @param point adapter point
      */
    function addAdapter(address adapter, uint256 point) external onlyRole(MANAGER) {
        require(adapter != address(0), "adapter cannot be zero address");
        require(point > 0, "point cannot be zero");
        for (uint256 i = 0; i < adapters.length; i++) {
            require(adapters[i].adapter != adapter, "adapter already exists");
        }

        adapters.push(Adapter({
            adapter: adapter,
            active: true,
            point: point
        }));

        emit AddAdapter(adapter, point);
    }

    /**
      * @dev update adapter
      * @param index adapter index
      * @param active active status
      * @param point adapter point
      */
    function setAdapter(uint256 index, bool active, uint256 point) external onlyRole(MANAGER) {
        require(index < adapters.length, "index out of range");
        adapters[index].active = active;
        adapters[index].point = point;

        emit SetAdapter(adapters[index].adapter, active, point);
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

    /**
      * @dev rebalance token to adapters, only bot can call this function
      */
    function rebalance() external onlyRole(BOT) {
        for (uint256 i = 0; i < adapters.length; i++) {
            IAdapter(adapters[i].adapter).withdrawAll();
        }
        uint256 amount = IERC20(token).balanceOf(address(this));

        if (amount > 0) {
            _distribute(amount);
        }

        emit ReBalance(amount);
    }

    /**
      * @dev harvest token, only bot can call this function
      */
    function harvest() external onlyRole(BOT) {
        // withdraw all token from adapters
        for (uint256 i = 0; i < adapters.length; i++) {
            IAdapter(adapters[i].adapter).withdrawAll();
        }

        uint256 totalAmount = IERC20(token).balanceOf(address(this));
        // if total amount > net deposit amount, transfer fee to fee receiver
        if (totalAmount > netDepositAmount) {
            uint256 fee = totalAmount - netDepositAmount;
            IERC20(token).safeTransfer(feeReceiver, fee);

            _distribute(netDepositAmount);

            emit Harvest(fee);
        }
    }

    /**
      * @dev emergency withdraw token from adapters
      * @param index adapter index
      */
    function emergencyWithdraw(uint256 index) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(index < adapters.length, "index out of range");
        uint256 amount = IAdapter(adapters[index].adapter).withdrawAll();

        IERC20(token).safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

}
