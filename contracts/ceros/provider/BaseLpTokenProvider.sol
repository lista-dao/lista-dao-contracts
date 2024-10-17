// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

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
import "../interfaces/IHelioTokenProvider.sol";
import "../../masterVault/interfaces/IMasterVault.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


abstract contract BaseLpTokenProvider is IHelioTokenProvider,
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

    /**
     * Variables
     */
    // Tokens
    address public certToken; // original token, e.g FDUSD
    ICertToken public collateralToken; // (clisXXX, e.g clisFDUSD)
    IDao public dao;
    // account > delegation { delegateTo, amount }
    mapping(address => Delegation) public delegation;
    // delegateTo account > sum delegated amount on this address
    mapping(address => uint256) public delegatedCollateral;
    // user account > sum collateral of user
    mapping(address => uint256) public userCollateral;

    /**
     * DEPOSIT
     */
    function _provide(uint256 _amount) internal returns (uint256) {
        require(_amount > 0, "zero deposit amount");

        IERC20(certToken).safeTransferFrom(msg.sender, address(this), _amount);
        // deposit ceToken as collateral
        uint256 collateralAmount = _provideCollateral(msg.sender, msg.sender, _amount);

        emit Deposit(msg.sender, _amount, collateralAmount);
        return collateralAmount;
    }

    function _provide(uint256 _amount, address _delegateTo) internal returns (uint256) {
        require(_amount > 0, "zero deposit amount");
        require(_delegateTo != address(0), "delegateTo cannot be zero address");
        require(
            delegation[msg.sender].delegateTo == _delegateTo ||
            delegation[msg.sender].amount == 0, // first time, clear old delegatee
            "delegateTo is differ from the current one"
        );

        IERC20(certToken).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 userCollateral = _provideCollateral(msg.sender, _delegateTo, _amount);

        Delegation storage delegation = delegation[msg.sender];
        delegation.delegateTo = _delegateTo;
        delegation.amount += userCollateral;
        delegatedCollateral[_delegateTo] += userCollateral;

        emit Deposit(msg.sender, _amount, userCollateral);
        return userCollateral;
    }

    /**
     * @dev deposit certToken to dao, mint collateral tokens to delegateTo
     * by default cert token to collateral token rate is 1:1
     *
     * @param _account account who deposit certToken
     * @param _holder collateral token holder
     * @param _amount cert token amount to deposit
     */
    function _provideCollateral(address _account, address _holder, uint256 _amount)
        virtual
        internal
        returns (uint256)
    {
        // all deposit data will be recorded on behalf of `account`
        dao.deposit(_account, certToken, _amount);
        // collateralTokenHolder can be account or delegateTo
        collateralToken.mint(_holder, _amount);
        userCollateral[_account] += _amount;

        return _amount;
    }

    function _delegateAllTo(address _newDelegateTo) internal {
        require(_newDelegateTo != address(0), "delegateTo cannot be zero address");
        // get user total deposit
        uint256 userCollateral = userCollateral[msg.sender];
        require(userCollateral > 0, "zero deposit amount");

        Delegation storage currentDelegation = delegation[msg.sender];
        address currentDelegateTo = currentDelegation.delegateTo;

        // Step 1. burn all tokens
        if (currentDelegation.amount > 0) {
            // burn delegatee's token
            collateralToken.burn(currentDelegateTo, currentDelegation.amount);
            delegatedCollateral[currentDelegateTo] -= currentDelegation.amount;
            // burn self's token
            if (userCollateral > currentDelegation.amount) {
                _safeBurnCollateral(msg.sender, userCollateral - currentDelegation.amount);
            }
        } else {
            _safeBurnCollateral(msg.sender, userCollateral);
        }

        // Step 2. save new delegatee and mint all tokens to delegatee
        if (_newDelegateTo == msg.sender) {
            // mint all to self
            collateralToken.mint(msg.sender, userCollateral);
            // remove delegatee
            delete delegation[msg.sender];
        } else {
            // mint all to new delegatee
            collateralToken.mint(_newDelegateTo, userCollateral);
            // save delegatee's info
            currentDelegation.delegateTo = _newDelegateTo;
            currentDelegation.amount = userCollateral;
            delegatedCollateral[_newDelegateTo] += userCollateral;
        }

        emit ChangeDelegateTo(msg.sender, currentDelegateTo, _newDelegateTo);
    }

    /**
     * RELEASE
     */
    function _release(address _recipient, uint256 _amount) internal returns (uint256) {
        require(_recipient != address(0));
        require(_amount > 0, "zero withdrawal amount");

        _withdrawCollateral(msg.sender, _amount);
        IERC20(certToken).safeTransfer(_recipient, _amount);
        emit Withdrawal(msg.sender, _recipient, _amount);
        return _amount;
    }

    function _withdrawCollateral(address _account, uint256 _amount) internal {
        dao.withdraw(_account, address(certToken), _amount);
        _burnCollateral(_account, _amount);
    }

    /**
     * Burn collateral Token from both delegator and delegateTo
     * @dev burns delegatee's collateralToken first, then delegator's
     * by default cert token to collateral token rate is 1:1
     *
     * @param _account collateral token owner
     * @param _amount cert token amount to burn
     */
    function _burnCollateral(address _account, uint256 _amount) virtual internal {
        Delegation storage delegation = delegation[_account];
        if (delegation.amount > 0) {
            uint256 delegatedAmount = delegation.amount;
            uint256 delegateeBurn = _amount > delegatedAmount ? delegatedAmount : _amount;
            // burn delegatee's token, update delegated amount
            collateralToken.burn(delegation.delegateTo, delegateeBurn);
            delegation.amount -= delegateeBurn;
            delegatedCollateral[delegation.delegateTo] -= delegateeBurn;
            // burn delegator's token
            if (_amount > delegateeBurn) {
                _safeBurnCollateral(_account, _amount - delegateeBurn);
            }
            userCollateral[_account] -= _amount;
        } else {
            // no delegation, only burn from account
            _safeBurnCollateral(_account, _amount);
            userCollateral[_account] -= _amount;
        }
    }

    /**
     * DAO FUNCTIONALITY
     */
    function _liquidation(address _recipient, uint256 _amount) internal {
        require(_recipient != address(0));
        IERC20(certToken).safeTransfer(_recipient, _amount);
        emit Liquidation(_recipient, _amount);
    }

    function _daoBurn(address _account, uint256 _amount) internal {
        require(_account != address(0));
        _burnCollateral(_account, _amount);
    }
    function _daoMint(address _account, uint256 _amount) internal {
        require(_account != address(0));
        collateralToken.mint(_account, _amount);
    }

    /**
     * @dev to make sure existing users who do not have enough collateralToken can still burn
     * only the available amount excluding delegated part will be burned
     *
     * @param _account collateral token holder
     * @param _amount amount to burn
     */
    function _safeBurnCollateral(address _account, uint256 _amount) virtual internal {
        uint256 availableBalance = collateralToken.balanceOf(_account) - delegatedCollateral[_account];
        if (_amount <= availableBalance) {
            collateralToken.burn(_account, _amount);
        } else if (availableBalance > 0) {
            // existing users do not have enough collateralToken
            collateralToken.burn(_account, availableBalance);
        }
    }

    function changeCertToken(address _ceToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(certToken).approve(address(dao), 0);
        certToken = _ceToken;
        IERC20(certToken).approve(address(dao), type(uint256).max);
        emit ChangeCertToken(_ceToken);
    }
    function changeCollateralToken(address _collateralToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        collateralToken = ICertToken(_collateralToken);
        emit ChangeCollateralToken(_collateralToken);
    }
    function changeDao(address _dao) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(certToken).approve(address(dao), 0);
        dao = IDao(_dao);
        IERC20(certToken).approve(address(dao), type(uint256).max);
        emit ChangeDao(_dao);
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

    // storage gap, declared fields: 6/20
    uint256[14] __gap;
}
