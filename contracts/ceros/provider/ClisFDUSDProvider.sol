// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IVault.sol";
import "../interfaces/IDex.sol";
import "../interfaces/IDao.sol";
import "../interfaces/IHelioProviderV2.sol";
import "../interfaces/IBNBStakingPool.sol";
import "../interfaces/ICertToken.sol";
import "../../masterVault/interfaces/IMasterVault.sol";
import {BaseClisTokenProvider} from "./BaseClisTokenProvider.sol";


contract ClisFDUSDProvider is BaseClisTokenProvider {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address collateralToken,
        address ceToken,
        address daoAddress
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _certToken = ceToken;
        _collateralToken = ICertToken(collateralToken);
        _dao = IDao(daoAddress);

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
     * RELEASE
     * withdraw given amount of certToken to recipient address
     * given amount collateral token will be burned from caller's address
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
        _daoMint(account, amount);
    }
}
