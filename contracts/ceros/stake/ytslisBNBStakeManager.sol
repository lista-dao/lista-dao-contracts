// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/ILpToken.sol";


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

    // token to lp token exchange rate
    uint128 public exchangeRate;
    // rate of lpToken to user
    uint128 public userLpTokenRate;
    // should be a mpc wallet address
    address public lpTokenReserveAddress;

    address public token;
    ILpToken public lpToken; // (default clisBNB)
    // account > total staked
    mapping(address => uint256) public balanceOf;
    // account > delegation { delegateTo, amount }
    mapping(address => Delegation) public delegation;
    // user account > sum lpToken of user (including delegated)
    mapping(address => uint256) public userLp;
    // user account > sum reserved lpToken
    mapping(address => uint256) public userReservedLp;
    // total reserved lpToken
    uint256 public totalReservedLp;

    /**
     * Events
     */
    event Staked(address indexed account, uint256 certAmount, uint256 userLp, uint256 reservedLp);
    event Unstaked(address indexed account, uint256 certAmount, uint256 userLp, uint256 reservedLp);
    event ChangeDelegateTo(address account, address oldDelegatee, address newDelegatee, uint256 amount);
    event SyncUserLp(address account, uint256 userLp, uint256 reservedLp);

    event ChangeExchangeRate(uint128 rate);
    event ChangeUserLpTokenRate(uint128 rate);
    event ChangeLpTokenReserveAddress(address newAddress);
    event ChangeToken(address token);
    event ChangeLpToken(address lpToken);

    function initialize(
        address _admin,
        address _manager,
        address _pauser,
        address _token,
        address _lpToken,
        address _lpTokenReserveAddress,
        uint128 _exchangeRate,
        uint128 _lpTokenRate
    ) public initializer {
        require(_admin != address(0), "admin cannot be a zero address");
        require(_manager != address(0), "manager cannot be a zero address");
        require(_pauser != address(0), "pauser cannot be a zero address");
        require(_token != address(0), "token cannot be a zero address");
        require(_lpToken != address(0), "lpToken cannot be a zero address");
        require(_lpTokenReserveAddress != address(0), "lpTokenReserveAddress cannot be a zero address");
        require(_exchangeRate > 0, "invalid exchangeRate");
        require(_lpTokenRate > 0 && _lpTokenRate <= 1e18, "invalid userLpTokenRate");

        __Pausable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER, _manager);
        _grantRole(PAUSER, _pauser);

        token = _token;
        lpToken = ILpToken(_lpToken);
        lpTokenReserveAddress = _lpTokenReserveAddress;
        exchangeRate = _exchangeRate;
        userLpTokenRate = _lpTokenRate;
    }

    /**
    * stake given amount of token to contract
    * given amount lp token will be mint to caller's address according to _exchangeRate
    *
    * @param _certAmount amount to deposit
    * @return lp token amount minted to caller
    */
    function stake(uint256 _certAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(_certAmount > 0, "zero stake amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), _certAmount);
        _syncLpToken(msg.sender);
        (uint256 userPart, uint256 reservedPart) = _provideLp(msg.sender, msg.sender, _certAmount);
        balanceOf[msg.sender] += _certAmount;
        emit Staked(msg.sender, _certAmount, userPart, reservedPart);
        return userPart;
    }

    /**
    * stake given amount of token to contract
    * given amount lp token will be mint to delegateTo address according to _exchangeRate
    *
    * @param _certAmount amount to deposit
    * @param _delegateTo target address of lp tokens
    * @return lp token amount minted to delegateTo
    */
    function stake(uint256 _certAmount, address _delegateTo)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(_certAmount > 0, "zero stake amount");
        require(_delegateTo != address(0), "delegateTo cannot be a zero address");

        IERC20(token).safeTransferFrom(msg.sender, address(this), _certAmount);
        _syncLpToken(msg.sender);
        (uint256 userPart, uint256 reservedPart) = _provideLp(msg.sender, _delegateTo, _certAmount);
        balanceOf[msg.sender] += _certAmount;
        Delegation storage delegation = delegation[msg.sender];
        delegation.delegateTo = _delegateTo;
        delegation.amount += userPart;

        emit Staked(msg.sender, _certAmount, userPart, reservedPart);
        return userPart;
    }

    /**
     * provide lp token to given address
     */
    function _provideLp(address _account, address _holder, uint256 _amount)
        private
        returns (uint256, uint256)
    {
        uint256 totalLpAmount = _amount * exchangeRate / RATE_DENOMINATOR;
        uint256 holderLpAmount = totalLpAmount * userLpTokenRate / RATE_DENOMINATOR;
        if (holderLpAmount > 0) {
            lpToken.mint(_holder, holderLpAmount);
            userLp[_account] += holderLpAmount;
        }

        uint256 reservedLpAmount = totalLpAmount - holderLpAmount;
        if (reservedLpAmount > 0) {
            lpToken.mint(lpTokenReserveAddress, reservedLpAmount);
            userReservedLp[_account] += reservedLpAmount;
            totalReservedLp += reservedLpAmount;
        }

        return (holderLpAmount, reservedLpAmount);
    }

    /**
    * delegate all lp tokens to given address
    * @param _newDelegateTo new target address of lp tokens
    */
    function delegateAllTo(address _newDelegateTo)
        external
        whenNotPaused
        nonReentrant
    {
        require(_newDelegateTo != address(0), "delegateTo cannot be zero address");
        _syncLpToken(msg.sender);

        // get user total lp
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
                lpToken.burn(msg.sender, userTotalLp - currentDelegation.amount);
            }
        } else {
            lpToken.burn(msg.sender, userTotalLp);
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

        emit ChangeDelegateTo(msg.sender, currentDelegateTo, _newDelegateTo, userTotalLp);
    }

    /**
    * unstake given amount of tokens to caller address
    * @param _certAmount amount of tokens
    */
    function unstake(uint256 _certAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return _unstake(_certAmount, msg.sender);
    }

    /**
     * unstake given amount of tokens to recipient address
     * @param _certAmount amount of tokens
     * @param _recipient recipient address
     */
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

        _syncLpToken(msg.sender);
        (uint256 userPart, uint256 reservedPart) = _burnLp(msg.sender, _certAmount);

        balanceOf[msg.sender] -= _certAmount;
        IERC20(token).safeTransfer(_recipient, _certAmount);

        emit Unstaked(msg.sender, _certAmount, userPart, reservedPart);
        return _certAmount;
    }

    /**
     * Burn Lp Token from both delegator and delegateTo
     * @dev burns delegatee's lpToken first, then delegator's
     * @param _account lp owner
     * @param _certAmount cert token amount
     */
    function _burnLp(address _account, uint256 _certAmount)
        private
        returns (uint256, uint256)
    {
        uint256 lpAmount = _certAmount * exchangeRate / RATE_DENOMINATOR;
        uint256 userPart = lpAmount * userLpTokenRate / RATE_DENOMINATOR;
        uint256 reservePart = lpAmount - userPart;
        uint256 userCurrentReserved = userReservedLp[_account];
        Delegation storage delegation = delegation[_account];
        if (reservePart > 0) {
            lpToken.burn(lpTokenReserveAddress, reservePart);
            userReservedLp[_account] -= reservePart;
            totalReservedLp -= reservePart;
        }

        if (delegation.amount > 0) {
            uint256 delegatedAmount = delegation.amount;
            uint256 delegateeBurn = userPart > delegatedAmount ? delegatedAmount : userPart;
            // burn delegatee's token, update delegated amount
            lpToken.burn(delegation.delegateTo, delegateeBurn);
            delegation.amount -= delegateeBurn;
            // burn delegator's token
            if (userPart > delegateeBurn) {
                lpToken.burn(_account, userPart - delegateeBurn);
            }
            userLp[_account] -= userPart;
        } else {
            // no delegation, only burn from account
            lpToken.burn(_account, userPart);
            userLp[_account] -= userPart;
        }

        return (userPart, reservePart);
    }

    /**
     * @dev sync user's lp token with contract state
     * @param _account user account
     */
    function syncUserLp(address _account) external {
        bool synced = _syncLpToken(_account);
        require(synced, "already synced");
    }

    /**
     * @dev check if user's lp token is synced with contract
     * @param _account user account
     * @return true if user's lp token is synced
     */
    function isUserLpSynced(address _account) external view returns (bool) {
        uint256 userTotalLp = balanceOf[_account] * exchangeRate / RATE_DENOMINATOR;
        uint256 expectUserPart = userTotalLp * userLpTokenRate / RATE_DENOMINATOR;
        uint256 expectReservePart = userTotalLp - expectUserPart;

        return userLp[_account] == expectUserPart && userReservedLp[_account] == expectReservePart;
    }

    /**
     * @dev sync user's lp token with contract state
     * @param _account user account
     * @return true if user's lp token is synced
     */
    function _syncLpToken(address _account) private returns (bool){
        uint256 userTotalLp = balanceOf[_account] * exchangeRate / RATE_DENOMINATOR;
        uint256 expectUserPart = userTotalLp * userLpTokenRate / RATE_DENOMINATOR;
        uint256 expectReservePart = userTotalLp - expectUserPart;
        uint256 userPart = userLp[_account];
        uint256 reservePart = userReservedLp[_account];
        if (userPart == expectUserPart && reservePart == expectReservePart) {
            return false;
        }

        // considering burn and mint with delta requires more if-else branches
        // so here just burn all and re-mint all
        if (reservePart > 0) {
            lpToken.burn(lpTokenReserveAddress, reservePart);
            userReservedLp[_account] = 0;
            totalReservedLp -= reservePart;
        }

        Delegation storage delegation = delegation[_account];
        uint256 currentDelegateAmount = delegation.amount;
        if (userPart > 0) {
            if (currentDelegateAmount > 0) {
                lpToken.burn(delegation.delegateTo, currentDelegateAmount);
                delegation.amount = 0;
            }
            uint256 userSelf = userPart - delegation.amount;
            if (userSelf > 0) {
                lpToken.burn(_account, userSelf);
            }
        }

        // re-mint
        if (expectReservePart > 0) {
            lpToken.mint(lpTokenReserveAddress, expectReservePart);
            userReservedLp[_account] = expectReservePart;
            totalReservedLp += expectReservePart;
        }

        if (expectUserPart > 0) {
            if (delegation.delegateTo != address(0)) {
                lpToken.mint(delegation.delegateTo, expectUserPart);
                delegation.amount = expectUserPart;
            } else {
                lpToken.mint(_account, expectUserPart);
            }
            userLp[_account] = expectUserPart;
        }

        emit SyncUserLp(_account, userLp[_account], userReservedLp[_account]);
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
    function changeLpToken(address _lpToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_lpToken != address(0), "lpToken cannot be a zero address");

        lpToken = ILpToken(_lpToken);
        emit ChangeLpToken(_lpToken);
    }

    function changeToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_token != address(0), "token cannot be a zero address");

        token = _token;
        emit ChangeToken(_token);
    }

    function changeExchangeRate(uint128 _exchangeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_exchangeRate > 0, "exchangeRate invalid");

        exchangeRate = _exchangeRate;
        emit ChangeExchangeRate(exchangeRate);
    }

    function changeUserLpTokenRate(uint128 _userLpTokenRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_userLpTokenRate > 0 && _userLpTokenRate <= 1e18, "userLpTokenRate invalid");

        userLpTokenRate = _userLpTokenRate;
        emit ChangeUserLpTokenRate(userLpTokenRate);
    }

    /**
     * change lpTokenReserveAddress, all reserved lpToken will be burned from original address and be minted to new address
     * @param _lpTokenReserveAddress new lpTokenReserveAddress
     */
    function changeLpTokenReserveAddress(address _lpTokenReserveAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_lpTokenReserveAddress != address(0) && _lpTokenReserveAddress != lpTokenReserveAddress, "lpTokenReserveAddress invalid");
        if (totalReservedLp > 0) {
            lpToken.burn(lpTokenReserveAddress, totalReservedLp);
        }

        lpTokenReserveAddress = _lpTokenReserveAddress;
        if (totalReservedLp > 0) {
            lpToken.mint(lpTokenReserveAddress, totalReservedLp);
        }
        emit ChangeLpTokenReserveAddress(lpTokenReserveAddress);
    }

    /**
     * UUPSUpgradeable FUNCTIONALITY
     */
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
    }
}

