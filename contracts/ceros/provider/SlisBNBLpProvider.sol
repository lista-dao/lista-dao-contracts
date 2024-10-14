// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IVault.sol";
import "../interfaces/IDex.sol";
import "../interfaces/IDao.sol";
import "../interfaces/IHelioProviderV2.sol";
import "../interfaces/IBNBStakingPool.sol";
import "../interfaces/ICertToken.sol";
import "../../masterVault/interfaces/IMasterVault.sol";
import {BaseLpTokenProvider} from "./BaseLpTokenProvider.sol";


contract SlisBNBLpProvider is BaseLpTokenProvider {

    using SafeERC20 for IERC20;

    uint128 public constant _RATE_DENOMINATOR = 1e18;

    uint128 public _depositCollateralReserveRate;

    address public _collateralReserveAddress;

    mapping(address => uint256) public _userReservedAmount;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address collateralToken,
        address certToken,
        address daoAddress,
        address collateralReserveAddress,
        uint128 depositCollateralReserveRate
    ) public initializer {
        require(collateralToken != address(0), "collateralToken is the zero address");
        require(certToken != address(0), "certToken is the zero address");
        require(daoAddress != address(0), "daoAddress is the zero address");
        require(collateralReserveAddress != address(0), "collateralReserveAddress is the zero address");
        require(depositCollateralReserveRate <= 1e18, "too big rate number");

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _certToken = certToken;
        _collateralToken = ICertToken(collateralToken);
        _dao = IDao(daoAddress);
        _collateralReserveAddress = collateralReserveAddress;
        _depositCollateralReserveRate = depositCollateralReserveRate;

        IERC20(_certToken).approve(daoAddress, type(uint256).max);
    }

    /**
    * DEPOSIT
    * deposit given amount of certToken to provider
    * given amount collateral token will be mint to caller's address
    * @param amount amount to deposit
    */
    function provide(uint256 amount)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _provide(amount);
    }

    /**
    * deposit given amount of certToken to provider
    * given amount collateral token will be mint to delegateTo
    * @param amount amount to deposit
    * @param delegateTo target address of collateral tokens
    */
    function provide(uint256 amount, address delegateTo)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _provide(amount, delegateTo);
    }

    /**
     * @dev deposit certToken to dao, mint collateral tokens to delegateTo according to rate
     *
     */
    function _provideCollateral(address account, address holder, uint256 amount)
        internal
        override
        returns (uint256)
    {
        // all deposit data will be recorded on behalf of `account`
        // collateralTokenHolder can be account or delegateTo
        _dao.deposit(account, _certToken, amount);

        uint256 holderCollateralAmount = amount * _depositCollateralReserveRate / _RATE_DENOMINATOR;
        if (holderCollateralAmount > 0) {
            _collateralToken.mint(holder, holderCollateralAmount);
        }

        uint256 reservedCollateralAmount = amount - holderCollateralAmount;
        if (reservedCollateralAmount > 0) {
            _collateralToken.mint(_collateralReserveAddress, reservedCollateralAmount);
            _userReservedAmount[account] += reservedCollateralAmount;
        }

        return holderCollateralAmount;
    }

    /**
    * delegate all collateral tokens to given address
    * @param newDelegateTo new target address of collateral tokens
    */
    function delegateAllTo(address newDelegateTo)
        external
        override
        whenNotPaused
        nonReentrant
    {
        _delegateAllTo(newDelegateTo);
    }

    /**
    * total locked amount excluding user's reserved amount
    *
    * @param account deposit user address
    */
    function _getAvailableLocked(address account)
        internal
        override
        view
        returns (uint256)
    {
        return _dao.locked(_certToken, account) - _userReservedAmount[account];
    }

    /**
     * RELEASE
     * withdraw given amount of certToken to recipient address
     * given amount collateral token will be burned from caller's address
     *
     * @param recipient recipient address
     * @param amount amount to release
     */
    function release(address recipient, uint256 amount)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _release(recipient, amount);
    }

    /**
     * Burn collateral Token from both delegator and delegateTo
     * @dev burns delegatee's collateralToken first, then delegator's
     */
    function _burnCollateral(address account, uint256 amount)
        internal
        override
    {
        uint256 userPart = amount * _depositCollateralReserveRate / _RATE_DENOMINATOR;
        uint256 reservePart = amount - userPart;
        uint256 userTotalReserved = _userReservedAmount[account];

        if (reservePart > 0) {
            if (reservePart <= userTotalReserved) {
                _collateralToken.burn(_collateralReserveAddress, reservePart);
                _userReservedAmount[account] -= reservePart;
            } else if (userTotalReserved > 0) {
                _collateralToken.burn(_collateralReserveAddress, userTotalReserved);
                _userReservedAmount[account] = 0;
            }
        }

        if(_delegation[account].amount > 0) {
            uint256 delegatedAmount = _delegation[account].amount;
            uint256 delegateeBurn = userPart > delegatedAmount ? delegatedAmount : userPart;
            // burn delegatee's token, update delegated amount
            _collateralToken.burn(_delegation[account].delegateTo, delegateeBurn);
            _delegation[account].amount -= delegateeBurn;
            _delegatedAmount[_delegation[account].delegateTo] -= delegateeBurn;
            // burn delegator's token
            if (userPart > delegateeBurn) {
                _safeBurnCollateral(account, userPart - delegateeBurn);
            }
        } else {
            // no delegation, only burn from account
            _safeBurnCollateral(account, userPart);
        }
    }

    /**
     * DAO FUNCTIONALITY
     * transfer given amount of certToken to recipient
     * called by AuctionProxy.buyFromAuction
     * @param recipient recipient address
     * @param amount amount to liquidate
     */
    function liquidation(address recipient, uint256 amount)
        external
        override
        whenNotPaused
        onlyProxy
        nonReentrant
    {
        _liquidation(recipient, amount);
    }

    /**
     * burn given amount of collateral token from account
     * called by AuctionProxy.startAuction
     * @param account collateral token holder
     * @param amount amount to burn
     */
    function daoBurn(address account, uint256 amount)
        external
        override
        whenNotPaused
        onlyProxy
        nonReentrant
    {
        _daoBurn(account, amount);
    }

    /**
     * mint given amount of collateral token to account
     * @param account collateral token receiver
     * @param amount amount to mint
     */
    function daoMint(address account, uint256 amount)
        external
        override
        whenNotPaused
        onlyProxy
        nonReentrant
    {
        uint256 holderCollateralAmount = amount * _depositCollateralReserveRate / _RATE_DENOMINATOR;
        if (holderCollateralAmount > 0) {
            _daoMint(account, amount);
        }

        uint256 reservedCollateralAmount = amount - holderCollateralAmount;
        if (reservedCollateralAmount > 0) {
            _daoMint(_collateralReserveAddress, reservedCollateralAmount);
            _userReservedAmount[account] += reservedCollateralAmount;
        }
    }
}
