// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IVault} from "../interfaces/IVault.sol";
import {IDao} from "../interfaces/IDao.sol";
import {IHelioProviderV2} from "../interfaces/IHelioProviderV2.sol";
import {ILpToken} from "../interfaces/ILpToken.sol";
import {IHelioTokenProvider} from "../interfaces/IHelioTokenProvider.sol";


abstract contract BaseTokenProvider is IHelioTokenProvider,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    uint128 public constant RATE_DENOMINATOR = 1e18;
    // manager role
    bytes32 public constant MANAGER = keccak256("MANAGER");
    // pause role
    bytes32 public constant PAUSER = keccak256("PAUSER");
    // proxy role
    bytes32 public constant PROXY = keccak256("PROXY");

    /**
     * Variables
     */
    // Tokens
    address public token; // original token, e.g FDUSD
    ILpToken public lpToken; // (clisXXX, e.g clisFDUSD)
    // interaction address
    IDao public dao;
    // account > delegation { delegateTo, amount }
    mapping(address => Delegation) public delegation;
    // user account > sum lpTokens of user including delegated part
    mapping(address => uint256) public userLp;

    /**
     * DEPOSIT
     */
    /**
    * deposit given amount of token to provider
    * given amount lp token will be mint to caller's address
    * @param _amount amount to deposit
    */
    function provide(uint256 _amount)
        external
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(_amount > 0, "zero deposit amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        // do sync before balance modified
        _syncLp(msg.sender);
        // deposit token as lp
        uint256 lpAmount = _provideCollateral(msg.sender, msg.sender, _amount);

        emit Deposit(msg.sender, _amount, lpAmount);
        return lpAmount;
    }

    /**
    * deposit given amount of token to provider
    * given amount lp token will be mint to delegateTo
    * @param _amount amount to deposit
    * @param _delegateTo target address of lp tokens
    */
    function provide(uint256 _amount, address _delegateTo)
        external
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(_amount > 0, "zero deposit amount");
        require(_delegateTo != address(0), "delegateTo cannot be zero address");
        require(_delegateTo != msg.sender, "delegateTo cannot be self");
        require(
            delegation[msg.sender].delegateTo == _delegateTo ||
            delegation[msg.sender].amount == 0, // first time, clear old delegatee
            "delegateTo is differ from the current one"
        );

        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        // do sync before balance modified
        _syncLp(msg.sender);
        uint256 userPartLp = _provideCollateral(msg.sender, _delegateTo, _amount);

        Delegation storage userDelegation = delegation[msg.sender];
        userDelegation.delegateTo = _delegateTo;
        userDelegation.amount += userPartLp;

        emit Deposit(msg.sender, _amount, userPartLp);
        return userPartLp;
    }

    /**
     * @dev deposit token to dao, mint lp tokens to delegateTo
     * by default token to lp token rate is 1:1
     *
     * @param _account account who deposit token
     * @param _holder lp token holder
     * @param _amount token amount to deposit
     */
    function _provideCollateral(address _account, address _holder, uint256 _amount)
        virtual
        internal
        returns (uint256)
    {
        // all deposit data will be recorded on behalf of `account`
        dao.deposit(_account, token, _amount);
        // lpTokenHolder can be account or delegateTo
        lpToken.mint(_holder, _amount);
        userLp[_account] += _amount;

        return _amount;
    }

    /**
    * delegate all collateral tokens to given address
    * @param _newDelegateTo new target address of collateral tokens
    */
    function delegateAllTo(address _newDelegateTo)
        external
        virtual
        whenNotPaused
        nonReentrant
    {
        require(_newDelegateTo != address(0), "delegateTo cannot be zero address");
        _syncLp(msg.sender);
        // get user total deposit
        uint256 userTotalLp = userLp[msg.sender];
        require(userTotalLp > 0, "zero lp to delegate");

        Delegation storage currentDelegation = delegation[msg.sender];
        address currentDelegateTo = currentDelegation.delegateTo;

        // Step 1. burn all tokens
        if (currentDelegation.amount > 0) {
            // burn delegatee's token
            lpToken.burn(currentDelegateTo, currentDelegation.amount);
            // burn self's token
            if (userTotalLp > currentDelegation.amount) {
                _safeBurnLp(msg.sender, userTotalLp - currentDelegation.amount);
            }
        } else {
            _safeBurnLp(msg.sender, userTotalLp);
        }

        // Step 2. save new delegatee and mint all tokens to delegatee
        if (_newDelegateTo == msg.sender) {
            // mint all to self
            lpToken.mint(msg.sender, userTotalLp);
            // remove delegatee
            delete delegation[msg.sender];
        } else {
            // mint all to new delegatee
            lpToken.mint(_newDelegateTo, userTotalLp);
            // save delegatee's info
            currentDelegation.delegateTo = _newDelegateTo;
            currentDelegation.amount = userTotalLp;
        }

        emit ChangeDelegateTo(msg.sender, currentDelegateTo, _newDelegateTo);
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
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(_recipient != address(0));
        require(_amount > 0, "zero withdrawal amount");

        _withdrawLp(msg.sender, _amount);
        IERC20(token).safeTransfer(_recipient, _amount);
        emit Withdrawal(msg.sender, _recipient, _amount);
        return _amount;
    }

    function _withdrawLp(address _account, uint256 _amount) virtual internal {
        _syncLp(msg.sender);
        dao.withdraw(_account, address(token), _amount);
        _burnLp(_account, _amount);
    }

    /**
     * Burn lp Token from both delegator and delegateTo
     * @dev burns delegatee's lpToken first, then delegator's
     * by default token to lp token rate is 1:1
     *
     * @param _account lp token owner
     * @param _amount token amount to burn, token to lpToken rate is 1:1 by default
     */
    function _burnLp(address _account, uint256 _amount) virtual internal {
        Delegation storage userDelegation = delegation[_account];
        if (userDelegation.amount > 0) {
            uint256 delegatedAmount = userDelegation.amount;
            uint256 delegateeBurn = _amount > delegatedAmount ? delegatedAmount : _amount;
            // burn delegatee's token, update delegated amount
            lpToken.burn(userDelegation.delegateTo, delegateeBurn);
            userDelegation.amount -= delegateeBurn;
            // burn delegator's token
            if (_amount > delegateeBurn) {
                _safeBurnLp(_account, _amount - delegateeBurn);
            }
            userLp[_account] -= _amount;
        } else {
            // no delegation, only burn from account
            _safeBurnLp(_account, _amount);
            userLp[_account] -= _amount;
        }
    }

    /**
     * DAO FUNCTIONALITY
     * transfer given amount of token to recipient
     * called by AuctionProxy.buyFromAuction
     *
     * @param _recipient recipient address
     * @param _amount amount to liquidate
     */
    function liquidation(address _recipient, uint256 _amount)
        external
        virtual
        nonReentrant
        whenNotPaused
        onlyRole(PROXY)
    {
        require(_recipient != address(0));
        IERC20(token).safeTransfer(_recipient, _amount);
        emit Liquidation(_recipient, _amount);
    }

    /**
     * burn given amount of collateral token from account
     * called by AuctionProxy.startAuction
     *
     * @param _account collateral token holder
     * @param _amount amount to burn
     */
    function daoBurn(address _account, uint256 _amount)
        external
        virtual
        nonReentrant
        whenNotPaused
        onlyRole(PROXY)
    {
        require(_account != address(0));
        _syncLp(_account);
    }

    /**
     * @dev to make sure existing users who do not have enough lpToken can still burn
     * only the available amount excluding delegated part will be burned
     *
     * @param _account lp token holder
     * @param _amount amount to burn
     */
    function _safeBurnLp(address _account, uint256 _amount) virtual internal {
        uint256 availableBalance = userLp[_account] - delegation[_account].amount;
        if (_amount <= availableBalance) {
            lpToken.burn(_account, _amount);
        } else if (availableBalance > 0) {
            // existing users do not have enough lpToken
            lpToken.burn(_account, availableBalance);
        }
    }

    /**
     * @dev mint/burn lpToken to sync user's lpToken with token balance
     *
     * @param _account user address to sync
     */
    function _syncLp(address _account) internal virtual returns (bool) {
        uint256 userExpectLp = dao.locked(token, _account);
        uint256 userCurrentLp = userLp[_account];
        if (userExpectLp == userCurrentLp) {
            return false;
        }

        Delegation storage currentDelegation = delegation[_account];
        uint256 currentDelegateLp = currentDelegation.amount;
        uint256 currentUserSelfLp = userCurrentLp - currentDelegateLp;
        uint256 expectDelegateLp = userCurrentLp > 0 ? userExpectLp * currentDelegateLp / userCurrentLp : 0;
        uint256 expectUserSelfLp = userExpectLp - expectDelegateLp;
        if (currentDelegateLp > expectDelegateLp) {
            lpToken.burn(currentDelegation.delegateTo, currentDelegateLp - expectDelegateLp);
            currentDelegation.amount = expectDelegateLp;
        } else if (currentDelegateLp < expectDelegateLp) {
            lpToken.mint(currentDelegation.delegateTo, expectDelegateLp - currentDelegateLp);
            currentDelegation.amount = expectDelegateLp;
        }

        if (currentUserSelfLp > expectUserSelfLp) {
            _safeBurnLp(_account, currentUserSelfLp - expectUserSelfLp);
        } else if (currentUserSelfLp < expectUserSelfLp) {
            lpToken.mint(_account, expectUserSelfLp - currentUserSelfLp);
        }

        userLp[_account] = userExpectLp;
        emit SyncUserLp(_account, userExpectLp);
        return true;
    }

    /**
     * PAUSABLE FUNCTIONALITY
     */
    function pause() external onlyRole(PAUSER) {
        _pause();
    }
    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused() ? _unpause() : _pause();
    }

    /**
     * UUPSUpgradeable FUNCTIONALITY
     */
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
    }

    // storage gap, declared fields: 5/50
    uint256[45] __gap;
}
