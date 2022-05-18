// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IDex.sol";
import "./interfaces/IDao.sol";
import "./interfaces/ICerosRouter.sol";
import "./interfaces/IHelioProvider.sol";
import "./interfaces/IBinancePool.sol";
import "./interfaces/ICertToken.sol";

contract HelioProvider is
    IHelioProvider,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /**
     * Variables
     */

    address private _operator;

    // Tokens
    address private _certToken;
    address private _ceToken;
    ICertToken private _collateralToken; // (default hBNB)

    ICerosRouter private _ceRouter;
    IDao private _dao;
    IBinancePool private _pool;

    /**
     * Modifiers
     */

    modifier onlyOperator() {
        require(
            msg.sender == owner() || msg.sender == _operator,
            "Operator: not allowed"
        );
        _;
    }

    modifier onlyDao() {
        require(
            msg.sender == owner() || msg.sender == address(_dao),
            "Dao: not allowed"
        );
        _;
    }

    function initialize(
        address collateralToken,
        address certToken,
        address ceToken,
        address ceRouter,
        address daoAddress,
        address pool
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _operator = msg.sender;
        _collateralToken = ICertToken(collateralToken);
        _certToken = certToken;
        _ceToken = ceToken;
        _ceRouter = ICerosRouter(ceRouter);
        _dao = IDao(daoAddress);
        _pool = IBinancePool(pool);
        IERC20(_ceToken).approve(daoAddress, type(uint256).max);
    }

    /**
     * DEPOSIT
     */

    function provide()
        external
        payable
        override
        nonReentrant
        returns (uint256 value)
    {
        value = _ceRouter.deposit{value: msg.value}();
        // deposit ceToken as collateral
        _provideCollateral(msg.sender, value);
        emit Deposit(msg.sender, value);
        return value;
    }

    function provideInABNBc(uint256 amount)
        external
        override
        nonReentrant
        returns (uint256 value)
    {
        value = _ceRouter.depositABNBc(msg.sender, amount);
        // deposit ceToken as collateral
        _provideCollateral(msg.sender, value);
        emit Deposit(msg.sender, value);
        return value;
    }

    /**
     * CLAIM
     */

    // claim in aBNBc
    function claimInABNBc(address recipient)
        external
        override
        nonReentrant
        onlyOperator
        returns (uint256 yields)
    {
        yields = _ceRouter.claim(recipient);
        emit Claim(recipient, yields);
        return yields;
    }

    /**
     * WITHDRAWAL
     */

    // withdrawal in BNB via staking pool
    function release(address recipient, uint256 amount)
        external
        override
        nonReentrant
        returns (uint256 realAmount)
    {
        uint256 minumunUnstake = _pool.getMinimumStake();
        require(
            amount >= minumunUnstake,
            "value must be greater than min unstake amount"
        );
        _withdrawCollateral(msg.sender, amount);
        _ceRouter.withdraw(recipient, amount);
        emit Withdrawal(msg.sender, recipient, realAmount);
        return realAmount;
    }

    function releaseInABNBc(address recipient, uint256 amount)
        external
        override
        nonReentrant
        returns (uint256 value)
    {
        _withdrawCollateral(msg.sender, amount);
        _ceRouter.withdrawABNBc(recipient, amount);
        emit Withdrawal(msg.sender, recipient, amount);
        return value;
    }

    /**
     * DAO FUNCTIONALITY
     */

    function liquidation(address recipient, uint256 amount)
        external
        override
        onlyDao
        nonReentrant
    {
        _ceRouter.withdrawABNBc(recipient, amount);
    }

    function daoBurn(address account, uint256 value)
        external
        override
        onlyDao
        nonReentrant
    {
        _collateralToken.burn(account, value);
    }

    function daoMint(address account, uint256 value)
        external
        override
        onlyDao
        nonReentrant
    {
        _collateralToken.mint(account, value);
    }

    function _provideCollateral(address account, uint256 amount) internal {
        _dao.deposit(account, address(_ceToken), amount);
        _collateralToken.mint(account, amount);
    }

    function _withdrawCollateral(address account, uint256 amount) internal {
        _dao.withdraw(account, address(_ceToken), amount);
        _collateralToken.burn(account, amount);
    }

    function changeDao(address dao) external onlyOwner {
        _dao = IDao(dao);
        emit ChangeDao(dao);
    }

    function changeCeToken(address ceToken) external onlyOwner {
        _ceToken = ceToken;
        emit ChangeCeToken(ceToken);
    }

    function changeCollateralToken(address collateralToken) external onlyOwner {
        _collateralToken = ICertToken(collateralToken);
        emit ChangeCollateralToken(collateralToken);
    }
}
