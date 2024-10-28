// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDao} from "../interfaces/IDao.sol";
import {ILpToken} from "../interfaces/ILpToken.sol";
import {BaseLpTokenProvider} from "./BaseLpTokenProvider.sol";

/**
 * @title SlisBNBLpProvider
 * @dev In comparison to BaseLpTokenProvider, SlisBNBLpProvider has two major differences:
 * 1. token to lpToken rate is not 1:1 and modifiable
 * 2. user's lpToken will be minted to itself(delegatee) and lpReserveAddress according to userLpRate
 */
contract SlisBNBLpProvider is BaseLpTokenProvider {
    using SafeERC20 for IERC20;
    // token to lpToken exchange rate
    uint128 public exchangeRate;
    // rate of lpToken to user when deposit
    uint128 public userLpRate;
    // should be a mpc wallet address
    address public lpReserveAddress;
    // user account > sum reserved lpToken
    mapping(address => uint256) public userReservedLp;
    // total reserved lpToken
    uint256 public totalReservedLp;

    /**
     * Events
     */
    event SyncUserLpWithReserve(address account, uint256 userLp, uint256 reservedLp);
    event ChangeExchangeRate(uint128 rate);
    event ChangeUserLpRate(uint128 rate);
    event ChangeLpReserveAddress(address newAddress);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _proxy,
        address _pauser,
        address _lpToken,
        address _token,
        address _daoAddress,
        address _lpReserveAddress,
        uint128 _exchangeRate,
        uint128 _userLpRate
    ) public initializer {
        require(_admin != address(0), "admin is the zero address");
        require(_proxy != address(0), "proxy is the zero address");
        require(_pauser != address(0), "pauser is the zero address");
        require(_lpToken != address(0), "lpToken is the zero address");
        require(_token != address(0), "token is the zero address");
        require(_daoAddress != address(0), "daoAddress is the zero address");
        require(_lpReserveAddress != address(0), "lpReserveAddress is the zero address");
        require(_exchangeRate > 0, "exchangeRate invalid");
        require(_userLpRate <= 1e18, "too big rate number");

        __Pausable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PROXY, _proxy);
        _grantRole(PAUSER, _pauser);

        token = _token;
        lpToken = ILpToken(_lpToken);
        dao = IDao(_daoAddress);
        lpReserveAddress = _lpReserveAddress;
        exchangeRate = _exchangeRate;
        userLpRate = _userLpRate;

        IERC20(token).approve(_daoAddress, type(uint256).max);
    }

    /**
    * DEPOSIT
    * deposit given amount of token to provider
    * given amount lp token will be mint to caller's address
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
    * deposit given amount of token to provider
    * given amount lp token will be mint to delegateTo
    * @param _amount amount to deposit
    * @param _delegateTo target address of lp tokens
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
     * @dev deposit token to dao, mint lp tokens to delegateTo according to rate
     *
     * @param _account account who deposit token
     * @param _holder lp token holder
     * @param _amount token amount to deposit
     */
    function _provideLp(address _account, address _holder, uint256 _amount)
        internal
        override
        returns (uint256)
    {
        // all deposit data will be recorded on behalf of `_account`
        // lpTokenHolder can be account or delegateTo
        dao.deposit(_account, token, _amount);
        uint256 lpAmount = _amount * exchangeRate / RATE_DENOMINATOR;
        uint256 holderLpAmount = lpAmount * userLpRate / RATE_DENOMINATOR;
        if (holderLpAmount > 0) {
            lpToken.mint(_holder, holderLpAmount);
            userLp[_account] += holderLpAmount;
        }

        uint256 reservedLpAmount = lpAmount - holderLpAmount;
        if (reservedLpAmount > 0) {
            lpToken.mint(lpReserveAddress, reservedLpAmount);
            userReservedLp[_account] += reservedLpAmount;
            totalReservedLp += reservedLpAmount;
        }

        return holderLpAmount;
    }

    /**
    * delegate all lp tokens to given address
    * @param _newDelegateTo new target address of lp tokens
    */
    function delegateAllTo(address _newDelegateTo)
        external
        override
        whenNotPaused
        nonReentrant
    {
        _delegateAllTo(_newDelegateTo);
    }

    /**
     * RELEASE
     * withdraw given amount of token to recipient address
     * given amount lp token will be burned from caller's address
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

    /**
     * Burn lp token from both delegator and delegateTo
     *
     * @dev burns delegatee's lpToken first, then delegator's
     */
    function _burnLp(address _account, uint256 _amount)
        internal
        override
    {
        uint256 totalLpAmount = _amount * exchangeRate / RATE_DENOMINATOR;
        uint256 userPart = totalLpAmount * userLpRate / RATE_DENOMINATOR;
        uint256 reservePart = totalLpAmount - userPart;
        uint256 userTotalReserved = userReservedLp[_account];
        if (reservePart > 0) {
            lpToken.burn(lpReserveAddress, reservePart);
            userReservedLp[_account] -= reservePart;
            totalReservedLp -= reservePart;
        }

        if (userPart > 0) {
            if (delegation[_account].amount > 0) {
                uint256 delegatedAmount = delegation[_account].amount;
                uint256 delegateeBurn = userPart > delegatedAmount ? delegatedAmount : userPart;
                // burn delegatee's token, update delegated amount
                lpToken.burn(delegation[_account].delegateTo, delegateeBurn);
                delegation[_account].amount -= delegateeBurn;
                // burn delegator's token
                if (userPart > delegateeBurn) {
                    _safeBurnLp(_account, userPart - delegateeBurn);
                }
                userLp[_account] -= userPart;
            } else {
                // no delegation, only burn from account
                _safeBurnLp(_account, userPart);
                userLp[_account] -= userPart;
            }
        }
    }

    function syncUserLp(address _account) external {
        bool synced = _syncLp(_account);
        require(synced, "already synced");
    }

    /**
     * check if user lp token is synced with token balance
     *
     * @param _account lp token owner
     */
    function isUserLpSynced(address _account) external view returns (bool) {
        uint256 totalTokenBalance = dao.locked(token, _account);
        uint256 userTotalLp = totalTokenBalance * exchangeRate / RATE_DENOMINATOR;
        uint256 expectUserPart = userTotalLp * userLpRate / RATE_DENOMINATOR;
        uint256 expectReservePart = userTotalLp - expectUserPart;

        return userLp[_account] == expectUserPart && userReservedLp[_account] == expectReservePart;
    }

    /**
     * @dev considering burn and mint with delta requires more if-else branches
     * so here just burn all and re-mint all
     *
     * @param _account user address to sync
     */
    function _syncLp(address _account) internal override returns (bool) {
        uint256 totalTokenBalance = dao.locked(token, _account);
        uint256 userTotalLp = totalTokenBalance * exchangeRate / RATE_DENOMINATOR;
        uint256 expectUserLp = userTotalLp * userLpRate / RATE_DENOMINATOR;
        uint256 expectReserveLp = userTotalLp - expectUserLp;
        uint256 reservePart = userReservedLp[_account];
        uint256 userPart = userLp[_account];
        if (userPart == expectUserLp && reservePart == expectReserveLp) {
            return false;
        }

        // burn all first
        if (reservePart > 0) {
            lpToken.burn(lpReserveAddress, reservePart);
            userReservedLp[_account] = 0;
            totalReservedLp -= reservePart;
        }

        Delegation storage delegation = delegation[_account];
        uint256 currentDelegateLp = delegation.amount;
        address currentDelegateTo = delegation.delegateTo;
        if (userPart > 0) {
            if (currentDelegateLp > 0) {
                lpToken.burn(currentDelegateTo, currentDelegateLp);
                delegation.amount = 0;
            }
            uint256 userSelf = userPart - currentDelegateLp;
            if (userSelf > 0) {
                lpToken.burn(_account, userSelf);
            }
            userLp[_account] = 0;
        }

        // re-mint
        if (expectReserveLp > 0) {
            lpToken.mint(lpReserveAddress, expectReserveLp);
            userReservedLp[_account] = expectReserveLp;
            totalReservedLp += expectReserveLp;
        }

        uint256 expectDelegateLp = userPart > 0 ? expectUserLp * currentDelegateLp / userPart : 0;
        uint256 expectUserSelfLp = expectUserLp - expectDelegateLp;
        if (expectDelegateLp > 0) {
            lpToken.mint(currentDelegateTo, expectDelegateLp);
            delegation.amount = expectDelegateLp;
        }
        if (expectUserSelfLp > 0) {
            lpToken.mint(_account, expectUserSelfLp);
        }

        userLp[_account] = expectUserLp;
        emit SyncUserLpWithReserve(_account, expectUserLp, expectReserveLp);
        return true;
    }

    /**
     * DAO FUNCTIONALITY
     * transfer given amount of token to recipient
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
     * burn given amount of token from account
     * called by AuctionProxy.startAuction
     *
     * @param _account lp token holder
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

    function changeExchangeRate(uint128 _exchangeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_exchangeRate > 0, "exchangeRate invalid");

        exchangeRate = _exchangeRate;
        emit ChangeExchangeRate(exchangeRate);
    }

    function changeUserLpRate(uint128 _userLpRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_userLpRate > 0 && _userLpRate <= 1e18, "userLpRate invalid");

        userLpRate = _userLpRate;
        emit ChangeUserLpRate(userLpRate);
    }

    /**
     * change lpReserveAddress, all reserved lpToken will be burned from original address and be minted to new address
     * @param _lpTokenReserveAddress new lpTokenReserveAddress
     */
    function changeLpReserveAddress(address _lpTokenReserveAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_lpTokenReserveAddress != address(0) && _lpTokenReserveAddress != lpReserveAddress, "lpTokenReserveAddress invalid");
        if (totalReservedLp > 0) {
            lpToken.burn(lpReserveAddress, totalReservedLp);
            lpToken.mint(_lpTokenReserveAddress, totalReservedLp);
        }
        lpReserveAddress = _lpTokenReserveAddress;
        emit ChangeLpReserveAddress(lpReserveAddress);
    }
}
