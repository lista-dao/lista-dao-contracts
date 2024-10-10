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
import "../interfaces/IHelioTokenProvider.sol";
import "../../masterVault/interfaces/IMasterVault.sol";


abstract contract BaseClisTokenProvider is IHelioTokenProvider,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    /**
     * Variables
     */
    // Tokens
    address public _certToken; // original token, e.g FDUSD
    ICertToken public _collateralToken; // (clisXXX, e.g clisFDUSD)
    IDao public _dao;
    // a multi-sig wallet which can pause the contract in case of emergency
    address public _guardian;
    address public _proxy;
    // account > delegation { delegateTo, amount }
    mapping(address => Delegation) public _delegation;
    // delegateTo account > sum delegated amount on this address
    mapping(address => uint256) public _delegatedAmount;

    /**
     * Modifiers
     */
    modifier onlyProxy() {
        require(
            msg.sender == owner() || msg.sender == _proxy,
            "Proxy: not allowed"
        );
        _;
    }

    modifier onlyGuardian() {
        require(
            msg.sender == _guardian,
            "not guardian"
        );
        _;
    }

    /**
     * DEPOSIT
     */
    function _provide(uint256 amount) internal returns (uint256) {
        require(amount > 0, "zero deposit amount");

        IERC20(_certToken).safeTransferFrom(msg.sender, address(this), amount);
        // deposit ceToken as collateral
        _provideCollateral(msg.sender, msg.sender, amount);
        emit Deposit(msg.sender, amount);
        return amount;
    }

    function _provide(uint256 amount, address delegateTo) internal returns (uint256) {
        require(amount > 0, "zero deposit amount");
        require(delegateTo != address(0), "delegateTo cannot be zero address");
        require(
            _delegation[msg.sender].delegateTo == delegateTo ||
            _delegation[msg.sender].amount == 0, // first time, clear old delegatee
            "delegateTo is differ from the current one"
        );

        IERC20(_certToken).safeTransferFrom(msg.sender, address(this), amount);
        _provideCollateral(msg.sender, delegateTo, amount);

        Delegation storage delegation = _delegation[msg.sender];
        delegation.delegateTo = delegateTo;
        delegation.amount += amount;
        _delegatedAmount[delegateTo] += amount;
        return amount;
    }

    function _delegateAllTo(address newDelegateTo) internal {
        require(newDelegateTo != address(0), "delegateTo cannot be zero address");
        // get user total deposit
        uint256 totalLocked = _dao.locked(_certToken, msg.sender);

        Delegation storage currentDelegation = _delegation[msg.sender];
        address currentDelegateTo = currentDelegation.delegateTo;

        // Step 1. burn all tokens
        if (currentDelegation.amount > 0) {
            // burn delegatee's token
            _collateralToken.burn(currentDelegateTo, currentDelegation.amount);
            _delegatedAmount[currentDelegateTo] -= currentDelegation.amount;
            // burn self's token
            if (totalLocked > currentDelegation.amount) {
                _safeBurnCollateral(msg.sender, totalLocked - currentDelegation.amount);
            }
        } else {
            _safeBurnCollateral(msg.sender, totalLocked);
        }

        // Step 2. save new delegatee and mint all tokens to delegatee
        if (newDelegateTo == msg.sender) {
            // mint all to self
            _collateralToken.mint(msg.sender, totalLocked);
            // remove delegatee
            delete _delegation[msg.sender];
        } else {
            // mint all to new delegatee
            _collateralToken.mint(newDelegateTo, totalLocked);
            // save delegatee's info
            currentDelegation.delegateTo = newDelegateTo;
            currentDelegation.amount = totalLocked;
            _delegatedAmount[newDelegateTo] += totalLocked;
        }

        emit ChangeDelegateTo(msg.sender, currentDelegateTo, newDelegateTo);
    }

    /**
     * RELEASE
     */
    function _release(address recipient, uint256 amount) internal returns (uint256) {
        require(recipient != address(0));
        require(amount > 0, "zero withdrawal amount");

        _withdrawCollateral(msg.sender, amount);
        IERC20(_certToken).safeTransfer(recipient, amount);
        emit Withdrawal(msg.sender, recipient, amount);
        return amount;
    }

    function _provideCollateral(address account, address delegateTo, uint256 amount) internal {
        // all deposit data will be recorded on behalf of `account`
        _dao.deposit(account, _certToken, amount);
        // collateralTokenHolder can be account or delegateTo
        _collateralToken.mint(delegateTo, amount);
    }

    function _withdrawCollateral(address account, uint256 amount) internal {
        _dao.withdraw(account, address(_certToken), amount);
        _burnCollateral(account, amount);
    }

    /**
     * DAO FUNCTIONALITY
     */
    function _liquidation(address recipient, uint256 amount) internal {
        require(recipient != address(0));
        IERC20(_certToken).safeTransfer(recipient, amount);
        emit Liquidation(recipient, amount);
    }

    function _daoBurn(address account, uint256 amount) internal {
        require(account != address(0));
        _burnCollateral(account, amount);
    }
    function _daoMint(address account, uint256 amount) internal {
        require(account != address(0));
        _collateralToken.mint(account, amount);
    }

    /**
     * Burn collateral Token from both delegator and delegateTo
     * @dev burns delegatee's collateralToken first, then delegator's
     */
    function _burnCollateral(address account, uint256 amount) internal {
        if(_delegation[account].amount > 0) {
            uint256 delegatedAmount = _delegation[account].amount;
            uint256 delegateeBurn = amount > delegatedAmount ? delegatedAmount : amount;
            // burn delegatee's token, update delegated amount
            _collateralToken.burn(_delegation[account].delegateTo, delegateeBurn);
            _delegation[account].amount -= delegateeBurn;
            _delegatedAmount[_delegation[account].delegateTo] -= delegateeBurn;
            // burn delegator's token
            if (amount > delegateeBurn) {
                _safeBurnCollateral(account, amount - delegateeBurn);
            }
        } else {
            // no delegation, only burn from account
            _safeBurnCollateral(account, amount);
        }
    }

    function _safeBurnCollateral(address account, uint256 amount) virtual internal {
        uint256 availableBalance = _collateralToken.balanceOf(account) - _delegatedAmount[account];
        if (amount <= availableBalance) {
            _collateralToken.burn(account, amount);
        } else if (availableBalance > 0) {
            // existing users do not have enough collateralToken
            _collateralToken.burn(account, availableBalance);
        }
    }

    function changeCertToken(address ceToken) external onlyOwner {
        IERC20(_certToken).approve(address(_dao), 0);
        _certToken = ceToken;
        IERC20(_certToken).approve(address(_dao), type(uint256).max);
        emit ChangeCertToken(ceToken);
    }
    function changeCollateralToken(address collateralToken) external onlyOwner {
        _collateralToken = ICertToken(collateralToken);
        emit ChangeCollateralToken(collateralToken);
    }
    function changeDao(address dao) external onlyOwner {
        IERC20(_certToken).approve(address(_dao), 0);
        _dao = IDao(dao);
        IERC20(_certToken).approve(address(_dao), type(uint256).max);
        emit ChangeDao(dao);
    }
    function changeProxy(address auctionProxy) external onlyOwner {
        require(auctionProxy != address(0), "zero address");

        _proxy = auctionProxy;
        emit ChangeProxy(auctionProxy);
    }
    function changeGuardian(address newGuardian) external onlyOwner {
        require(
            newGuardian != address(0) && _guardian != newGuardian,
            "guardian cannot be zero address or same as the current one"
        );

        address oldGuardian = _guardian;
        _guardian = newGuardian;
        emit ChangeGuardian(oldGuardian, newGuardian);
    }

    /**
     * PAUSABLE FUNCTIONALITY
     */
    function pause() external onlyGuardian {
        _pause();
    }
    function togglePause() external onlyOwner {
        paused() ? _unpause() : _pause();
    }

    // storage gap, declared fields: 6/20
    uint256[14] __gap;
}
