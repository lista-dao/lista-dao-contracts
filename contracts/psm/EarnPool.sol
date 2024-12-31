// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/ILisUSDPool.sol";
import "../interfaces/IPSM.sol";

contract EarnPool is AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  // token => psm
  mapping(address => address) public psm;

  address public lisUSDPool; // lisUSD pool address
  address public lisUSD; // lisUSD address

  bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
  bytes32 public constant PAUSER = keccak256("PAUSER"); // pause role

  event SetLisUSDPool(address lisUSDPool);
  event SetLisUSD(address lisUSD);
  event SetPSM(address token, address psm);
  event RemovePSM(address token);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev initialize contract
   * @param _admin admin address
   * @param _manager manager address
   * @param _lisUSDPool lisUSD pool address
   * @param _lisUSD lisUSD address
   */
  function initialize(
    address _admin,
    address _manager,
    address _pauser,
    address _lisUSDPool,
    address _lisUSD
  ) public initializer {
    require(_admin != address(0), "admin cannot be zero address");
    require(_manager != address(0), "manager cannot be zero address");
    require(_pauser != address(0), "pauser cannot be zero address");
    require(_lisUSDPool != address(0), "lisUSDPool cannot be zero address");
    require(_lisUSD != address(0), "lisUSD cannot be zero address");
    __AccessControl_init();
    __Pausable_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    _setupRole(MANAGER, _manager);
    _setupRole(PAUSER, _pauser);

    lisUSDPool = _lisUSDPool;
    lisUSD = _lisUSD;

    emit SetLisUSDPool(_lisUSDPool);
    emit SetLisUSD(_lisUSD);
  }

  /**
   * @dev deposit token to earn pool
   * @param token token address
   * @param amount token amount
   */
  function deposit(address token, uint256 amount) external whenNotPaused {
    require(amount > 0, "amount must be greater than zero");
    require(psm[token] != address(0), "psm not set");

    address account = msg.sender;
    // transfer token to earn pool
    IERC20(token).safeTransferFrom(account, address(this), amount);

    // convert token to lisUSD by psm
    IERC20(token).safeIncreaseAllowance(psm[token], amount);
    uint256 before = IERC20(lisUSD).balanceOf(address(this));
    IPSM(psm[token]).sell(amount);
    uint256 lisUSDAmount = IERC20(lisUSD).balanceOf(address(this)) - before;

    // deposit lisUSD to lisUSD pool
    IERC20(lisUSD).safeIncreaseAllowance(lisUSDPool, lisUSDAmount);
    ILisUSDPool(lisUSDPool).depositFor(token, account, lisUSDAmount);
  }

  /**
   * @dev pause contract
   */
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /**
   * @dev unpause contract
   */
  function unpause() external onlyRole(MANAGER) {
    _unpause();
  }

  /**
   * @dev set psm
   * @param _token token address
   * @param _psm psm address
   */
  function setPSM(address _token, address _psm) external onlyRole(MANAGER) {
    require(_token != address(0), "token cannot be zero address");
    require(_psm != address(0), "psm cannot be zero address");
    require(psm[_token] == address(0), "psm already set");
    require(IPSM(_psm).token() == _token, "psm token not match");
    psm[_token] = _psm;

    emit SetPSM(_token, _psm);
  }

  /**
   * @dev remove psm
   * @param _token token address
   */
  function removePSM(address _token) external onlyRole(MANAGER) {
    require(psm[_token] != address(0), "psm is not set");
    delete psm[_token];

    emit RemovePSM(_token);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
