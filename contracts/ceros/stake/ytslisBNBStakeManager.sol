// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/ICertToken.sol";


contract ytslisBNBStakeManager is
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    struct Delegation {
        address delegateTo; // who helps delegator to hold clisBNB, aka the delegatee
        uint256 amount;
    }

    using SafeERC20 for IERC20;

    uint128 public constant RATE_DENOMINATOR = 1e18;
    // manager role
    bytes32 public constant MANAGER = keccak256("MANAGER");
    // pause role
    bytes32 public constant PAUSER = keccak256("PAUSER");

    // cert token to collateral token exchange rate
    uint128 public exchangeRate;
    // rate of collateral to user
    uint128 public userCollateralRate;

    // should be a mpc wallet address
    address public collateralReserveAddress;

    address public certToken;
    ICertToken public collateralToken; // (default clisBNB)

    // account > total staked
    mapping(address => uint256) public balanceOf;

    // account > delegation { delegateTo, amount }
    mapping(address => Delegation) public delegation;

    // user account > sum collateral of user
    mapping(address => uint256) public userCollateral;

    // user account > sum reserved collateral
    mapping(address => uint256) public userReservedCollateral;

    /**
     * Events
     */
    event Staked(address indexed account, uint256 certAmount, uint256 userColl, uint256 reservedColl);
    event Unstaked(address indexed account, uint256 certAmount, uint256 userColl, uint256 reservedColl);
    event ChangeDelegateTo(address account, address oldDelegatee, address newDelegatee, uint256 amount);
    event SyncUserCollateral(address account, uint256 userColl, uint256 reservedColl);

    event ChangeExchangeRate(uint128 rate);
    event ChangeUserCollateralRate(uint128 rate);
    event ChangeCertToken(address certToken);
    event ChangeCollateralToken(address collateralToken);

    function initialize(
        address _admin,
        address _manager,
        address _pauser,
        address _certToken,
        address _collateralToken,
        address _collateralReserveAddress,
        uint128 _exchangeRate,
        uint128 _userCollateralRate
    ) public initializer {
        require(_admin != address(0), "admin cannot be a zero address");
        require(_manager != address(0), "manager cannot be a zero address");
        require(_pauser != address(0), "pauser cannot be a zero address");
        require(_certToken != address(0), "certToken cannot be a zero address");
        require(_collateralToken != address(0), "collateralToken cannot be a zero address");
        require(_collateralReserveAddress != address(0), "collateralReserveAddress cannot be a zero address");
        require(_exchangeRate > 0, "exchangeRate invalid");
        require(_userCollateralRate > 0 && _userCollateralRate <= 1e18, "userCollateralRate invalid");

        __Pausable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER, _manager);
        _grantRole(PAUSER, _pauser);

        certToken = _certToken;
        collateralToken = ICertToken(_collateralToken);
        collateralReserveAddress = _collateralReserveAddress;
        exchangeRate = _exchangeRate;
        userCollateralRate = _userCollateralRate;
    }

    /**
    * stake given amount of certToken to contract
    * given amount collateral token will be mint to caller's address according to _exchangeRate
    *
    * @param _certAmount amount to deposit
    * @return collateral amount minted to caller
    */
    function stake(uint256 _certAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(_certAmount > 0, "zero stake amount");

        IERC20(certToken).safeTransferFrom(msg.sender, address(this), _certAmount);
        _syncCollateral(msg.sender);
        (uint256 userPart, uint256 reservedPart) = _provideCollateral(msg.sender, msg.sender, _certAmount);
        balanceOf[msg.sender] += _certAmount;
        userCollateral[msg.sender] += userPart;
        userReservedCollateral[msg.sender] += reservedPart;

        emit Staked(msg.sender, _certAmount, userPart, reservedPart);
        return userPart;
    }

    /**
    * stake given amount of certToken to contract
    * given amount collateral token will be mint to delegateTo address according to _exchangeRate
    *
    * @param _certAmount amount to deposit
    * @param _delegateTo target address of collateral tokens
    * @return collateral amount minted to delegateTo
    */
    function stake(uint256 _certAmount, address _delegateTo)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(_certAmount > 0, "zero stake amount");
        require(_delegateTo != address(0), "delegateTo cannot be a zero address");

        IERC20(certToken).safeTransferFrom(msg.sender, address(this), _certAmount);
        _syncCollateral(msg.sender);
        (uint256 userPart, uint256 reservedPart) = _provideCollateral(msg.sender, _delegateTo, _certAmount);

        balanceOf[msg.sender] += _certAmount;
        userCollateral[msg.sender] += userPart;
        userReservedCollateral[msg.sender] += reservedPart;

        Delegation storage delegation = delegation[msg.sender];
        delegation.delegateTo = _delegateTo;
        delegation.amount += userPart;

        emit Staked(msg.sender, _certAmount, userPart, reservedPart);
        return userPart;
    }

    function _provideCollateral(address _account, address _holder, uint256 _amount)
        internal
        returns (uint256, uint256)
    {
        uint256 totalCollateralAmount = _amount * exchangeRate / RATE_DENOMINATOR;
        uint256 holderCollateralAmount = totalCollateralAmount * userCollateralRate / RATE_DENOMINATOR;
        if (holderCollateralAmount > 0) {
            collateralToken.mint(_holder, holderCollateralAmount);
        }

        uint256 reservedCollateralAmount = totalCollateralAmount - holderCollateralAmount;
        if (reservedCollateralAmount > 0) {
            collateralToken.mint(collateralReserveAddress, reservedCollateralAmount);
        }

        return (holderCollateralAmount, reservedCollateralAmount);
    }

    /**
    * delegate all collateral tokens to given address
    * @param _newDelegateTo new target address of collateral tokens
    */
    function delegateAllTo(address _newDelegateTo)
        external
        whenNotPaused
        nonReentrant
    {
        require(_newDelegateTo != address(0), "delegateTo cannot be zero address");
        _syncCollateral(msg.sender);

        // get user total collaterals
        uint256 totalCollateral = userCollateral[msg.sender];
        require(totalCollateral > 0, "zero collateral to delegate");

        Delegation storage currentDelegation = delegation[msg.sender];
        address currentDelegateTo = currentDelegation.delegateTo;
        // Step 1. burn all tokens
        if (currentDelegation.amount > 0) {
            // burn delegatee's token
            collateralToken.burn(currentDelegateTo, currentDelegation.amount);
            // burn self's token
            if (totalCollateral > currentDelegation.amount) {
                collateralToken.burn(msg.sender, totalCollateral - currentDelegation.amount);
            }
        } else {
            collateralToken.burn(msg.sender, totalCollateral);
        }

        // Step 2. save new delegatee and mint all tokens to delegatee
        if (_newDelegateTo == msg.sender) {
            // mint all to self
            collateralToken.mint(msg.sender, totalCollateral);
            // remove delegatee
            delete delegation[msg.sender];
        } else {
            // mint all to new delegatee
            collateralToken.mint(_newDelegateTo, totalCollateral);
            // save delegatee's info
            currentDelegation.delegateTo = _newDelegateTo;
            currentDelegation.amount = totalCollateral;
        }

        emit ChangeDelegateTo(msg.sender, currentDelegateTo, _newDelegateTo, totalCollateral);
    }

    function unstake(uint256 _certAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _unstake(_certAmount, msg.sender);
    }

    function unstake(uint256 _certAmount, address _recipient)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _unstake(_certAmount, _recipient);
    }

    function _unstake(uint256 _certAmount, address _recipient)
        internal
        returns (uint256)
    {
        require(_certAmount > 0, "zero withdrawal amount");
        require(_recipient != address(0), "recipient cannot be a zero address");
        require(balanceOf[msg.sender] >= _certAmount, "insufficient balance");

        _syncCollateral(msg.sender);
        (uint256 userPart, uint256 reservedPart) = _burnCollateral(msg.sender, _certAmount);

        balanceOf[msg.sender] -= _certAmount;
        IERC20(certToken).safeTransfer(_recipient, _certAmount);

        emit Unstaked(msg.sender, _certAmount, userPart, reservedPart);
        return _certAmount;
    }

    /**
     * Burn collateral Token from both delegator and delegateTo
     * @dev burns delegatee's collateralToken first, then delegator's
     * @param _account collateral owner
     * @param _certAmount cert token amount
     */
    function _burnCollateral(address _account, uint256 _certAmount)
        virtual
        internal
        returns (uint256, uint256)
    {
        uint256 userCertBalance = balanceOf[_account];
        uint256 collAmount = _certAmount * exchangeRate / RATE_DENOMINATOR;
        uint256 userPart = collAmount * userCollateralRate / RATE_DENOMINATOR;
        uint256 reservePart = collAmount - userPart;
        uint256 userTotalReserved = userReservedCollateral[_account];
        Delegation storage delegation = delegation[_account];
        if (userCertBalance == _certAmount) {
            // burn all when withdraw all cert
            if (userTotalReserved > 0) {
                collateralToken.burn(collateralReserveAddress, userTotalReserved);
                userReservedCollateral[_account] = 0;
            }

            uint256 delegatedAmount = delegation.amount;
            if (delegatedAmount > 0) {
                collateralToken.burn(delegation.delegateTo, delegatedAmount);
                delegation.amount = 0;
            }

            uint256 currentCollateral = userCollateral[_account];
            uint256 userBurn = currentCollateral - delegatedAmount;
            if (userBurn > 0) {
                collateralToken.burn(_account, userBurn);
            }

            userCollateral[_account] = 0;
            return (currentCollateral, userTotalReserved);
        }

        if (reservePart > 0) {
            if (userCertBalance == _certAmount) {
            } else if (reservePart <= userTotalReserved) {
                collateralToken.burn(collateralReserveAddress, reservePart);
                userReservedCollateral[_account] -= reservePart;
            } else if (userTotalReserved > 0) {
                collateralToken.burn(collateralReserveAddress, userTotalReserved);
                userReservedCollateral[_account] = 0;
            }
        }

        if (delegation.amount > 0) {
            uint256 delegatedAmount = delegation.amount;
            uint256 delegateeBurn = userPart > delegatedAmount ? delegatedAmount : userPart;
            // burn delegatee's token, update delegated amount
            collateralToken.burn(delegation.delegateTo, delegateeBurn);
            delegation.amount -= delegateeBurn;
            // burn delegator's token
            if (userPart > delegateeBurn) {
                collateralToken.burn(_account, userPart - delegateeBurn);
            }
            userCollateral[_account] -= userPart;
        } else {
            // no delegation, only burn from account
            collateralToken.burn(_account, userPart);
            userCollateral[_account] -= userPart;
        }

        return (userPart, reservePart);
    }

    function syncUserCollateral(address _account) external {
        bool synced = _syncCollateral(_account);
        require(synced, "already synced");
    }

    function isUserCollateralSynced(address _account) external view returns (bool) {
        uint256 userTotalCollateral = balanceOf[_account] * exchangeRate / RATE_DENOMINATOR;
        uint256 expectedUserPart = userTotalCollateral * userCollateralRate / RATE_DENOMINATOR;
        uint256 expectedReservedPart = userTotalCollateral - expectedUserPart;

        return userCollateral[_account] == expectedUserPart && userReservedCollateral[_account] == expectedReservedPart;
    }

    function _syncCollateral(address _account) internal returns (bool){
        uint256 userTotalCollateral = balanceOf[_account] * exchangeRate / RATE_DENOMINATOR;
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
                    userCollateral[_account] -= delegation.amount;
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
     * PAUSABLE FUNCTIONALITY
     */
    function pause() external onlyRole(PAUSER) {
        _pause();
    }

    function togglePause() external onlyRole(PAUSER) {
        paused() ? _unpause() : _pause();
    }
    /**
     * setters
     */
    function changeCollateralToken(address _collateralToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_collateralToken != address(0), "collateralToken cannot be a zero address");

        collateralToken = ICertToken(_collateralToken);
        emit ChangeCollateralToken(_collateralToken);
    }

    function changeCertToken(address _certToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_certToken != address(0), "certToken cannot be a zero address");

        certToken = _certToken;
        emit ChangeCertToken(_certToken);
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

    /**
     * UUPSUpgradeable FUNCTIONALITY
     */
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
    }
}

