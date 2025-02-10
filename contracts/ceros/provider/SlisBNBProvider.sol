// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDao} from "../interfaces/IDao.sol";
import {ILpToken} from "../interfaces/ILpToken.sol";
import {BaseTokenProvider} from "./BaseTokenProvider.sol";

/**
 * @title SlisBNBProvider
 * @dev In comparison to BaseLpTokenProvider, SlisBNBLpProvider has two major differences:
 * 1. token to lpToken rate is not 1:1 and modifiable
 * 2. user's lpToken will be minted to itself(delegatee) and lpReserveAddress according to userLpRate
 */
contract SlisBNBProvider is BaseTokenProvider {
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
        address _manager,
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
        require(_manager != address(0), "manager is the zero address");
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
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER, _manager);
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
     * @dev deposit token to dao, mint lp tokens to delegateTo according to rate
     *
     * @param _account account who deposit token
     * @param _holder lp token holder
     * @param _amount token amount to deposit
     */
    function _provideCollateral(address _account, address _holder, uint256 _amount)
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
     * @dev withdraw leftover collateral from Interaction contract; to support historical liquidated slisBnb urns
     */
    function withdrawLeftover() external whenNotPaused nonReentrant {
        uint256 leftover = dao.free(token, msg.sender);
        require(leftover > 0, "no leftover");
        uint256 amount = dao.withdraw(msg.sender, token, leftover);

        IERC20(token).safeTransfer(msg.sender, amount);
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
     * @dev mint/burn lpToken to sync user's lpToken with token balance
     *
     * @param _account user address to sync
     */
    function _syncLp(address _account) internal override returns (bool) {
        uint256 expectAllLp = dao.locked(token, _account) * exchangeRate / RATE_DENOMINATOR;
        uint256 expectUserLp = expectAllLp * userLpRate / RATE_DENOMINATOR;
        uint256 expectReserveLp = expectAllLp - expectUserLp;
        uint256 reservePart = userReservedLp[_account];
        uint256 userPart = userLp[_account];
        if (userPart == expectUserLp && reservePart == expectReserveLp) {
            return false;
        }

        // reservePart
        if (reservePart > expectReserveLp) {
            lpToken.burn(lpReserveAddress, reservePart - expectReserveLp);
            userReservedLp[_account] = expectReserveLp;
            totalReservedLp -= (reservePart - expectReserveLp);
        } else if (reservePart < expectReserveLp) {
            lpToken.mint(lpReserveAddress, expectReserveLp - reservePart);
            userReservedLp[_account] = expectReserveLp;
            totalReservedLp += (expectReserveLp - reservePart);
        }
        // user self and delegation
        Delegation storage userDelegation = delegation[_account];
        uint256 currentDelegateLp = userDelegation.amount;
        uint256 currentUserSelf = userPart - currentDelegateLp;
        uint256 expectDelegateLp = userPart > 0 ? expectUserLp * currentDelegateLp / userPart : 0;
        uint256 expectUserSelfLp = expectUserLp - expectDelegateLp;
        if (currentDelegateLp > expectDelegateLp) {
            lpToken.burn(userDelegation.delegateTo, currentDelegateLp - expectDelegateLp);
            userDelegation.amount = expectDelegateLp;
        } else if (currentDelegateLp < expectDelegateLp) {
            lpToken.mint(userDelegation.delegateTo, expectDelegateLp - currentDelegateLp);
            userDelegation.amount = expectDelegateLp;
        }
        if (currentUserSelf > expectUserSelfLp) {
            lpToken.burn(_account, currentUserSelf - expectUserSelfLp);
        } else if (currentUserSelf < expectUserSelfLp) {
            lpToken.mint(_account, expectUserSelfLp - currentUserSelf);
        }

        userLp[_account] = expectUserLp;
        emit SyncUserLpWithReserve(_account, expectUserLp, expectReserveLp);
        return true;
    }

    function changeExchangeRate(uint128 _exchangeRate) external onlyRole(MANAGER) {
        require(_exchangeRate > 0, "exchangeRate invalid");

        exchangeRate = _exchangeRate;
        emit ChangeExchangeRate(exchangeRate);
    }

    function changeUserLpRate(uint128 _userLpRate) external onlyRole(MANAGER) {
        require(_userLpRate <= 1e18, "userLpRate invalid");

        userLpRate = _userLpRate;
        emit ChangeUserLpRate(userLpRate);
    }

    /**
     * change lpReserveAddress, all reserved lpToken will be burned from original address and be minted to new address
     * @param _lpTokenReserveAddress new lpTokenReserveAddress
     */
    function changeLpReserveAddress(address _lpTokenReserveAddress) external onlyRole(MANAGER) {
        require(_lpTokenReserveAddress != address(0) && _lpTokenReserveAddress != lpReserveAddress, "lpTokenReserveAddress invalid");
        if (totalReservedLp > 0) {
            lpToken.burn(lpReserveAddress, totalReservedLp);
            lpToken.mint(_lpTokenReserveAddress, totalReservedLp);
        }
        lpReserveAddress = _lpTokenReserveAddress;
        emit ChangeLpReserveAddress(lpReserveAddress);
    }
}
