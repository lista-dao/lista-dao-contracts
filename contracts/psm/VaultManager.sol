// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IAdapter.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract VaultManager is ReentrancyGuardUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
  using SafeERC20 for IERC20;
  address public psm; // PSM address
  address public token; // token address

  struct Adapter {
    address adapter; // adapter address
    bool active; // active status
    uint256 point; // adapter point
  }

  Adapter[] public adapters; // adapter list

  bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
  bytes32 public constant BOT = keccak256("BOT"); // bot role

  event SetPSM(address psm);
  event SetToken(address token);
  event SetAdapter(address adapter, bool active, uint256 point);
  event AddAdapter(address adapter, uint256 point);
  event Deposit(uint256 amount);
  event Withdraw(address receiver, uint256 amount);
  event ReBalance(uint256 amount);
  event EmergencyWithdraw(address account, uint256 amount);

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
   */
  function initialize(address _admin, address _manager, address _psm, address _token) public initializer {
    require(_admin != address(0), "admin cannot be zero address");
    require(_manager != address(0), "manager cannot be zero address");
    require(_psm != address(0), "psm cannot be zero address");
    require(_token != address(0), "token cannot be zero address");
    __AccessControl_init();
    __UUPSUpgradeable_init();
    __ReentrancyGuard_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    _setupRole(MANAGER, _manager);

    psm = _psm;
    token = _token;

    emit SetPSM(_psm);
    emit SetToken(_token);
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
   * @dev deposit token to adapters, only PSM or manager can call this function
   * @param amount deposit amount
   */
  function deposit(uint256 amount) external nonReentrant onlyPSMOrManager {
    require(amount > 0, "deposit amount cannot be zero");

    // transfer token to this contract
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    _distribute(amount);

    emit Deposit(amount);
  }

  function _distribute(uint256 amount) private {
    uint256 remain = amount;
    uint256 totalPoint = getTotalPoint();

    if (totalPoint == 0) {
      return;
    }
    // deposit token to adapters by adapter point
    for (uint256 i = 0; i < adapters.length; i++) {
      if (adapters[i].active && adapters[i].point > 0) {
        // only active adapter can be used
        //  adapterAmount = depositAmount * point / totalPoint
        uint256 amt = Math.mulDiv(amount, adapters[i].point, totalPoint);
        if (amt > 0) {
          IERC20(token).safeIncreaseAllowance(adapters[i].adapter, amt);
          IAdapter(adapters[i].adapter).deposit(amt);
          remain -= amt;
        }
      }
    }
  }

  /**
   * @dev withdraw token from adapters, only PSM or manager can call this function
   * @param receiver receiver address
   * @param amount withdraw amount
   */
  function withdraw(address receiver, uint256 amount) external nonReentrant onlyPSMOrManager {
    require(amount > 0, "withdraw amount cannot be zero");

    uint256 remain = amount;
    uint256 vaultBalance = IERC20(token).balanceOf(address(this));
    if (vaultBalance >= amount) {
      // withdraw token from vault manager
      IERC20(token).safeTransfer(receiver, amount);
      remain = 0;
    } else {
      if (vaultBalance > 0) {
        IERC20(token).safeTransfer(receiver, vaultBalance);
        remain -= vaultBalance;
      }
    }

    if (remain > 0) {
      require(adapters.length > 0, "no adapter");
      // withdraw token from adapters
      uint256 startIdx = block.number % adapters.length;

      for (uint256 i = 0; i < adapters.length; i++) {
        uint256 idx = (startIdx + i) % adapters.length;
        // only active adapter can be used
        if (adapters[idx].active) {
          uint256 netDeposit = IAdapter(adapters[idx].adapter).netDepositAmount();
          if (netDeposit == 0) {
            continue;
          }
          if (netDeposit >= remain) {
            IAdapter(adapters[idx].adapter).withdraw(receiver, remain);
            remain = 0;
            break;
          } else {
            remain -= netDeposit;
            IAdapter(adapters[idx].adapter).withdraw(receiver, netDeposit);
          }
        }
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

    adapters.push(Adapter({ adapter: adapter, active: true, point: point }));

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
   * @dev get total net deposit amount
   */
  function getTotalNetDepositAmount() public view returns (uint256) {
    uint256 amount = IERC20(token).balanceOf(address(this));
    for (uint256 i = 0; i < adapters.length; i++) {
      amount += IAdapter(adapters[i].adapter).netDepositAmount();
    }
    return amount;
  }

  /**
   * @dev get total point
   */
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
   * @dev rebalance token to adapters, only bot can call this function
   */
  function rebalance() external onlyRole(BOT) {
    require(adapters.length > 0, "no adapter");

    for (uint256 i = 0; i < adapters.length; i++) {
      if (adapters[i].active) {
        IAdapter(adapters[i].adapter).withdrawAll();
      }
    }
    uint256 amount = IERC20(token).balanceOf(address(this));

    if (amount > 0) {
      _distribute(amount);
    }

    emit ReBalance(amount);
  }

  /**
   * @dev emergency withdraw token from adapters
   * @param index adapter index
   */
  function emergencyWithdraw(uint256 index) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(index < adapters.length, "index out of range");
    uint256 amount = IAdapter(adapters[index].adapter).withdrawAll() + IERC20(token).balanceOf(address(this));

    IERC20(token).safeTransfer(msg.sender, amount);

    emit EmergencyWithdraw(msg.sender, amount);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
