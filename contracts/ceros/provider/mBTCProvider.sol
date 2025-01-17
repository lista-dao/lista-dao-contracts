// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IDao } from "../interfaces/IDao.sol";
import { ILpToken } from "../interfaces/ILpToken.sol";
import { ICertToken } from "../interfaces/ICertToken.sol";

contract mBTCProvider is AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  // manager role
  bytes32 public constant MANAGER = keccak256("MANAGER");
  // pause role
  bytes32 public constant PAUSER = keccak256("PAUSER");
  // proxy role
  bytes32 public constant PROXY = keccak256("PROXY");

  // original token, mBTC
  address public token;
  // ceToken, cemBTC
  address public ceToken;
  // clisToken, clismBTC
  ILpToken public lpToken;

  // scale factor for token to lpToken conversion
  // mBTC has 8 decimals, cemBTC has 18 decimals
  // scale = 10 ** (18 - 8) = 10 ** 10
  uint256 public scale;

  // interaction address
  IDao public dao;

  event Deposit(address indexed account, uint256 amount, uint256 lpAmount);
  event Withdrawal(address indexed account, address indexed recipient, uint256 amount, uint256 lpAmount);
  event Liquidation(address indexed recipient, uint256 amount, uint256 lpAmount);

  function initialize(
    address _admin,
    address _manager,
    address _pauser,
    address _lpToken,
    address _ceToken,
    address _token,
    address _daoAddress
  ) public initializer {
    require(_admin != address(0), "admin is the zero address");
    require(_manager != address(0), "manager is the zero address");
    require(_pauser != address(0), "pauser is the zero address");
    require(_lpToken != address(0), "lpToken is the zero address");
    require(_ceToken != address(0), "ceToken is the zero address");
    require(_token != address(0), "token is the zero address");
    require(_daoAddress != address(0), "daoAddress is the zero address");

    __Pausable_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();
    __AccessControl_init();
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(MANAGER, _manager);
    _grantRole(PAUSER, _pauser);
    _grantRole(PROXY, _daoAddress);

    token = _token;
    ceToken = _ceToken;
    lpToken = ILpToken(_lpToken);
    dao = IDao(_daoAddress);

    uint8 tokenDecimals = IERC20Metadata(token).decimals();
    uint8 ceTokenDecimals = IERC20Metadata(ceToken).decimals();
    uint8 lpTokenDecimals = lpToken.decimals();

    require(ceTokenDecimals == lpTokenDecimals && ceTokenDecimals > tokenDecimals, "invalid decimals");

    uint256 diff = uint256(ceTokenDecimals - tokenDecimals);
    scale = 10 ** diff;

    IERC20(ceToken).approve(_daoAddress, type(uint256).max);
  }

  /**
   * @dev deposit given amount of token to provider
   * given amount lp token will be mint to caller's address
   * @param _amount mBTC amount to deposit
   */
  function provide(uint256 _amount) external virtual whenNotPaused nonReentrant returns (uint256) {
    require(_amount > 0, "zero deposit amount");

    // 1. transfer mBTC to provider
    IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);

    // 2. calculate lpToken amount; cemBTC amount is equal to lpToken amount
    uint256 lpAmount = _amount * scale;

    // 3. mint cemBTC and deposit to dao
    ICertToken(ceToken).mint(address(this), lpAmount);
    dao.deposit(msg.sender, ceToken, lpAmount);

    // 4. mint lpToken to caller
    lpToken.mint(msg.sender, lpAmount);

    emit Deposit(msg.sender, _amount, lpAmount);
    return lpAmount;
  }

  /**
   * @dev withdraw given amount of mBTC to recipient address
   * given amount lp token will be burned from caller's address
   *
   * @param _recipient recipient address
   * @param _amount mBTC amount to release
   */
  function release(address _recipient, uint256 _amount) external virtual whenNotPaused nonReentrant returns (uint256) {
    require(_recipient != address(0));
    require(_amount > 0, "zero withdrawal amount");

    // 1. calculate lpToken amount; cemBTC amount is equal to lpToken amount
    uint256 lpAmount = _amount * scale;

    // 2. transfer cemBTC from dao to provider and burn
    dao.withdraw(msg.sender, ceToken, lpAmount);
    ICertToken(ceToken).burn(address(this), lpAmount);

    // 3. burn cemBTC
    lpToken.burn(msg.sender, lpAmount);

    // 4. transfer mBTC to recipient
    IERC20(token).safeTransfer(_recipient, _amount);

    emit Withdrawal(msg.sender, _recipient, _amount, lpAmount);
    return _amount;
  }

  /**
   * @dev transfer given amount of token to recipient, called by AuctionProxy.buyFromAuction
   * @param _recipient recipient address
   * @param _lpAmount lp amount to liquidate
   */
  function liquidation(
    address _recipient,
    uint256 _lpAmount
  ) external virtual nonReentrant whenNotPaused onlyRole(PROXY) {
    require(_recipient != address(0));
    uint256 _amount = _lpAmount / scale;
    IERC20(token).safeTransfer(_recipient, _amount);

    emit Liquidation(_recipient, _amount, _lpAmount);
  }

  /**
   * @dev burn lp token from account called by AuctionProxy.startAuction
   * @param _account collateral token holder
   * @param _lpAmount lpToken amount to burn
   */
  function daoBurn(address _account, uint256 _lpAmount) external virtual nonReentrant whenNotPaused onlyRole(PROXY) {
    require(_account != address(0));
    lpToken.burn(_account, _lpAmount);
  }

  /**
   * @dev pause the contract
   */
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /**
   * @dev unpause the contract
   */
  function unpause() external onlyRole(MANAGER) {
    _unpause();
  }

  function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
