// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDao} from "../interfaces/IDao.sol";
import {ICertToken} from "../interfaces/ICertToken.sol";
import {BaseLpTokenProvider} from "./BaseLpTokenProvider.sol";


contract SlisBNBLpProvider is BaseLpTokenProvider {

    using SafeERC20 for IERC20;
    // ceToken to collateral token exchange rate
    uint128 public exchangeRate;

    uint128 public userCollateralRate;

    address public collateralReserveAddress;

    mapping(address => uint256) public userReservedCollateral;

    /**
     * Events
     */
    event SyncUserCollateral(address account, uint256 userColl, uint256 reservedColl);
    event ChangeExchangeRate(uint128 rate);
    event ChangeUserCollateralRate(uint128 rate);


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _proxy,
        address _pauser,
        address _collateralToken,
        address _ceToken,
        address _daoAddress,
        address _collateralReserveAddress,
        uint128 _exchangeRate,
        uint128 _userCollateralRate
    ) public initializer {
        require(_admin != address(0), "admin is the zero address");
        require(_proxy != address(0), "proxy is the zero address");
        require(_pauser != address(0), "pauser is the zero address");
        require(_collateralToken != address(0), "collateralToken is the zero address");
        require(_ceToken != address(0), "ceToken is the zero address");
        require(_daoAddress != address(0), "daoAddress is the zero address");
        require(_collateralReserveAddress != address(0), "collateralReserveAddress is the zero address");
        require(_exchangeRate > 0, "exchangeRate invalid");
        require(_userCollateralRate <= 1e18, "too big rate number");

        __Pausable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PROXY, _proxy);
        _grantRole(PAUSER, _pauser);

        ceToken = _ceToken;
        collateralToken = ICertToken(_collateralToken);
        dao = IDao(_daoAddress);
        collateralReserveAddress = _collateralReserveAddress;
        exchangeRate = _exchangeRate;
        userCollateralRate = _userCollateralRate;

        IERC20(ceToken).approve(_daoAddress, type(uint256).max);
    }

    /**
    * DEPOSIT
    * deposit given amount of ceToken to provider
    * given amount collateral token will be mint to caller's address
    * @param _amount amount to deposit
    */
    function provide(uint256 _amount)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _provide(_amount);
    }

    /**
    * deposit given amount of ceToken to provider
    * given amount collateral token will be mint to delegateTo
    * @param _amount amount to deposit
    * @param _delegateTo target address of collateral tokens
    */
    function provide(uint256 _amount, address _delegateTo)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _provide(_amount, _delegateTo);
    }

    /**
     * @dev deposit ceToken to dao, mint collateral tokens to delegateTo according to rate
     *
     * @param _account account who deposit ceToken
     * @param _holder collateral token holder
     * @param _amount ceToken amount to deposit
     */
    function _provideCollateral(address _account, address _holder, uint256 _amount)
        internal
        override
        returns (uint256)
    {
        // do sync before balance modified
        _syncCollateral(_account);
        // all deposit data will be recorded on behalf of `_account`
        // collateralTokenHolder can be account or delegateTo
        dao.deposit(_account, ceToken, _amount);
        uint256 totalCollateralAmount = _amount * exchangeRate / RATE_DENOMINATOR;
        uint256 holderCollateralAmount = totalCollateralAmount * userCollateralRate / RATE_DENOMINATOR;
        if (holderCollateralAmount > 0) {
            collateralToken.mint(_holder, holderCollateralAmount);
            userCollateral[_account] += holderCollateralAmount;
        }

        uint256 reservedCollateralAmount = totalCollateralAmount - holderCollateralAmount;
        if (reservedCollateralAmount > 0) {
            collateralToken.mint(collateralReserveAddress, reservedCollateralAmount);
            userReservedCollateral[_account] += reservedCollateralAmount;
        }

        return holderCollateralAmount;
    }

    /**
    * delegate all collateral tokens to given address
    * @param _newDelegateTo new target address of collateral tokens
    */
    function delegateAllTo(address _newDelegateTo)
        external
        override
        whenNotPaused
        nonReentrant
    {
        require(_newDelegateTo != address(0), "delegateTo cannot be zero address");

        _syncCollateral(msg.sender);
        _delegateAllTo(_newDelegateTo);
    }

    /**
     * RELEASE
     * withdraw given amount of ceToken to recipient address
     * given amount collateral token will be burned from caller's address
     *
     * @param _recipient recipient address
     * @param _amount amount to release
     */
    function release(address _recipient, uint256 _amount)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _release(_recipient, _amount);
    }

    function _withdrawCollateral(address _account, uint256 _amount) internal override {
        // do sync before balance modified
        _syncCollateral(_account);

        dao.withdraw(_account, address(ceToken), _amount);
        _burnCollateral(_account, _amount);
    }

    /**
     * Burn collateral Token from both delegator and delegateTo
     *
     * @dev burns delegatee's collateralToken first, then delegator's
     */
    function _burnCollateral(address _account, uint256 _amount)
        internal
        override
    {
        uint256 userCeBalance = dao.locked(ceToken, _account);
        uint256 totalCollateralAmount = _amount * exchangeRate / RATE_DENOMINATOR;
        uint256 userPart = totalCollateralAmount * userCollateralRate / RATE_DENOMINATOR;
        uint256 reservePart = totalCollateralAmount - userPart;
        uint256 userTotalReserved = userReservedCollateral[_account];

        if (reservePart > 0) {
            if (userCeBalance == _amount) {
                // burn all when withdraw all ceToken
                collateralToken.burn(collateralReserveAddress, userTotalReserved);
                userReservedCollateral[_account] = 0;
            } else if (reservePart <= userTotalReserved) {
                collateralToken.burn(collateralReserveAddress, reservePart);
                userReservedCollateral[_account] -= reservePart;
            } else if (userTotalReserved > 0) {
                collateralToken.burn(collateralReserveAddress, userTotalReserved);
                userReservedCollateral[_account] = 0;
            }
        }

        if(delegation[_account].amount > 0) {
            uint256 delegatedAmount = delegation[_account].amount;
            uint256 delegateeBurn = userPart > delegatedAmount ? delegatedAmount : userPart;
            // burn delegatee's token, update delegated amount
            collateralToken.burn(delegation[_account].delegateTo, delegateeBurn);
            delegation[_account].amount -= delegateeBurn;
            delegatedCollateral[delegation[_account].delegateTo] -= delegateeBurn;
            // burn delegator's token
            if (userPart > delegateeBurn) {
                _safeBurnCollateral(_account, userPart - delegateeBurn);
            }
        } else {
            // no delegation, only burn from account
            _safeBurnCollateral(_account, userPart);
        }

        if (userCollateral[_account] >= userPart) {
            userCollateral[_account] -= userPart;
        } else {
            userCollateral[_account] = 0;
        }
    }

    function syncUserCollateral(address _account) external {
        bool synced = _syncCollateral(_account);
        require(synced, "already synced");
    }

    /**
     * check if user collateral is synced with ceToken balance
     *
     * @param _account collateral token owner
     */
    function isUserCollateralSynced(address _account) external view returns (bool) {
        uint256 totalCeBalance = dao.locked(ceToken, _account);
        uint256 userTotalCollateral = totalCeBalance * exchangeRate / RATE_DENOMINATOR;
        uint256 expectedUserPart = userTotalCollateral * userCollateralRate / RATE_DENOMINATOR;
        uint256 expectedReservedPart = userTotalCollateral - expectedUserPart;

        return userCollateral[_account] == expectedUserPart && userReservedCollateral[_account] == expectedReservedPart;
    }

    function _syncCollateral(address _account) internal returns (bool) {
        uint256 totalCeBalance = dao.locked(ceToken, _account);
        uint256 userTotalCollateral = totalCeBalance * exchangeRate / RATE_DENOMINATOR;
        uint256 expectedUserPart = userTotalCollateral * userCollateralRate / RATE_DENOMINATOR;
        uint256 expectedReservedPart = userTotalCollateral - expectedUserPart;
        uint256 userPart = userCollateral[_account];
        uint256 reservedPart = userReservedCollateral[_account];

        if (userPart == expectedUserPart && reservedPart == expectedReservedPart) {
            return false;
        }

        // reserved part
        if (expectedReservedPart > reservedPart) {
            uint256 mintAmount = expectedReservedPart - reservedPart;
            collateralToken.mint(collateralReserveAddress, mintAmount);
            userReservedCollateral[_account] += mintAmount;
        } else if (expectedReservedPart < reservedPart) {
            uint256 burnAmount = reservedPart - expectedReservedPart;
            collateralToken.burn(collateralReserveAddress, burnAmount);
            userReservedCollateral[_account] -= burnAmount;
        }

        // user part
        Delegation storage delegation = delegation[_account];
        if (delegation.delegateTo != address(0)) {
            if (expectedUserPart > userPart) {
                uint256 mintAmount = expectedUserPart - userPart;
                collateralToken.mint(delegation.delegateTo, mintAmount);
                delegation.amount += mintAmount;
                userCollateral[_account] += mintAmount;
            } else if (expectedUserPart < userPart) {
                uint256 burnAmount = userPart - expectedUserPart;
                if (burnAmount <= delegation.amount) {
                    collateralToken.burn(delegation.delegateTo, burnAmount);
                    delegation.amount -= burnAmount;
                    userCollateral[_account] -= burnAmount;
                } else {
                    collateralToken.burn(delegation.delegateTo, delegation.amount);
                    collateralToken.burn(_account, burnAmount - delegation.amount);

                    delegation.amount = 0;
                    userCollateral[_account] -= burnAmount;
                }
            }
        } else {
            if (expectedUserPart > userPart) {
                uint256 mintAmount = expectedUserPart - userPart;
                collateralToken.mint(_account, mintAmount);
                userCollateral[_account] += mintAmount;
            } else if (expectedUserPart < userPart) {
                uint256 burnAmount = userPart - expectedUserPart;
                collateralToken.burn(_account, burnAmount);
                userCollateral[_account] -= burnAmount;
            }
        }

        emit SyncUserCollateral(_account, userCollateral[_account], userReservedCollateral[_account]);
        return true;
    }

    /**
     * DAO FUNCTIONALITY
     * transfer given amount of ceToken to recipient
     * called by AuctionProxy.buyFromAuction
     * @param _recipient recipient address
     * @param _amount amount to liquidate
     */
    function liquidation(address _recipient, uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
        onlyRole(PROXY)
    {
        _liquidation(_recipient, _amount);
    }

    /**
     * burn given amount of collateral token from account
     * called by AuctionProxy.startAuction
     * @param _account collateral token holder
     * @param _amount amount to burn
     */
    function daoBurn(address _account, uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
        onlyRole(PROXY)
    {
        _daoBurn(_account, _amount);
    }

    /**
     * mint given amount of collateral token to account
     * @param _account collateral token receiver
     * @param _amount amount to mint
     */
    function daoMint(address _account, uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
        onlyRole(PROXY)
    {
        uint256 holderCollateralAmount = _amount * userCollateralRate / RATE_DENOMINATOR;
        if (holderCollateralAmount > 0) {
            _daoMint(_account, _amount);
        }

        uint256 reservedCollateralAmount = _amount - holderCollateralAmount;
        if (reservedCollateralAmount > 0) {
            _daoMint(collateralReserveAddress, reservedCollateralAmount);
            userReservedCollateral[_account] += reservedCollateralAmount;
        }
    }

    function changeExchangeRate(uint128 _exchangeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_exchangeRate > 0, "exchangeRate invalid");

        exchangeRate = _exchangeRate;
        emit ChangeExchangeRate(exchangeRate);
    }

    function changeUserCollateralRate(uint128 _userCollateralRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_userCollateralRate > 0 && _userCollateralRate <= 1e18, "userCollateralRate invalid");

        userCollateralRate = _userCollateralRate;
        emit ChangeUserCollateralRate(userCollateralRate);
    }
}
