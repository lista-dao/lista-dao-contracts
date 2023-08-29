// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IDex.sol";
import "../interfaces/IDao.sol";
import "../interfaces/ICerosRouter.sol";
import "../interfaces/IHelioProviderV2.sol";
import "../interfaces/IBNBStakingPool.sol";
import "../interfaces/ICertToken.sol";
import "../../masterVault/interfaces/IMasterVault.sol";
contract HelioProviderV2 is
IHelioProviderV2,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{
    /**
     * Variables
     */
    address public _operator;
    // Tokens
    address public _certToken;
    address public _ceToken;
    ICertToken public _collateralToken; // (default hBNB)
    IMasterVault public _masterVault;
    IDao public _dao;
    IBNBStakingPool public _pool;
    address public _proxy;
    address public _liquidationStrategy;
    /**
     * Modifiers
     */
    modifier onlyProxy() {
        require(
            msg.sender == owner() || msg.sender == _proxy,
            "AuctionProxy: not allowed"
        );
        _;
    }
    function initialize(
        address collateralToken,
        address masterVault,
        address ceToken,
        address daoAddress
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _collateralToken = ICertToken(collateralToken);
        // _certToken = certToken;
        _ceToken = ceToken;
        _masterVault = IMasterVault(masterVault);
        _dao = IDao(daoAddress);
        // _pool = IMaticPool(pool);
        IERC20(_ceToken).approve(daoAddress, type(uint256).max);
    }
    /**
     * DEPOSIT
     */
    function provide()
    external
    payable
    override
    whenNotPaused
    nonReentrant
    returns (uint256 value)
    {
        value = _masterVault.depositETH{value: msg.value}();
        // deposit ceToken as collateral
        _provideCollateral(msg.sender, value);
        emit Deposit(msg.sender, value);
        return value;
    }
    /**
     * RELEASE
     */
    // withdrawal in BNB
    function release(address recipient, uint256 amount)
    external
    override
    whenNotPaused
    nonReentrant
    returns (uint256 realAmount)
    {
        require(recipient != address(0));
        uint256 minumumUnstake = _pool.getMinUnstake();
        require(
            amount >= minumumUnstake,
            "value must be greater than min unstake amount"
        );
        _withdrawCollateral(msg.sender, amount);
        realAmount = _masterVault.withdrawETH(recipient, amount);
        emit Withdrawal(msg.sender, recipient, amount);
        return realAmount;
    }

    /**
     * releaseInToken, recipient will get (aBNBc/stkBNB/snBNB/BNBx)
     */
    function releaseInToken(address strategy, address recipient, uint256 amount)
    external
    override
    whenNotPaused
    nonReentrant
    returns (uint256 realAmount)
    {
        require(recipient != address(0));
        _withdrawCollateral(msg.sender, amount);
        realAmount = _masterVault.withdrawInTokenFromStrategy(strategy, recipient, amount);
        emit WithdrawalInToken(msg.sender, recipient, amount);
        return realAmount;
    }

    //Estimate how much token(aBNBc/stkBNB/snBNB/BNBx) can get when call releaseInToken
    function estimateInToken(address strategy, uint256 amount) external view override returns(uint256) {
        return _masterVault.estimateInTokenFromStrategy(strategy, amount);
    }

    //Calculate the balance(aBNBc/stkBNB/snBNB/BNBx) in the strategy contract
    function balanceOfToken(address strategy) external view override returns(uint256) {
        return _masterVault.balanceOfTokenFromStrategy(strategy);
    }

    /**
     * DAO FUNCTIONALITY
     */
    function liquidation(address recipient, uint256 amount)
    external
    override
    onlyProxy
    whenNotPaused
    nonReentrant
    {
        require(recipient != address(0));
        // _masterVault.withdrawETH(recipient, amount);
        _masterVault.withdrawInTokenFromStrategy(_liquidationStrategy, recipient, amount);
        emit WithdrawalInToken(msg.sender, recipient, amount);
    }
    function daoBurn(address account, uint256 value)
    external
    override
    whenNotPaused
    onlyProxy
    nonReentrant
    {
        require(account != address(0));
        _collateralToken.burn(account, value);
    }
    function daoMint(address account, uint256 value)
    external
    override
    whenNotPaused
    onlyProxy
    nonReentrant
    {
        require(account != address(0));
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
    /**
     * PAUSABLE FUNCTIONALITY
     */
    function pause() external onlyOwner {
        _pause();
    }
    function unPause() external onlyOwner {
        _unpause();
    }
    /**
     * UPDATING FUNCTIONALITY
     */
    function changeDao(address dao) external onlyOwner {
        IERC20(_ceToken).approve(address(_dao), 0);
        _dao = IDao(dao);
        IERC20(_ceToken).approve(address(_dao), type(uint256).max);
        emit ChangeDao(dao);
    }
    function changeCeToken(address ceToken) external onlyOwner {
        IERC20(_ceToken).approve(address(_dao), 0);
        _ceToken = ceToken;
        IERC20(_ceToken).approve(address(_dao), type(uint256).max);
        emit ChangeCeToken(ceToken);
    }
    function changeProxy(address auctionProxy) external onlyOwner {
        _proxy = auctionProxy;
        emit ChangeProxy(auctionProxy);
    }
    function changeCollateralToken(address collateralToken) external onlyOwner {
        _collateralToken = ICertToken(collateralToken);
        emit ChangeCollateralToken(collateralToken);
    }
    function changeMasterVault(address masterVault) external onlyOwner {
        _masterVault = IMasterVault(masterVault);
        emit ChangeMasterVault(masterVault);
    }
    function changeBNBStakingPool(address pool) external onlyOwner {
        _pool = IBNBStakingPool(pool);
        emit ChangeBNBStakingPool(pool);
    }
    function changeLiquidationStrategy(address strategy) external onlyOwner {
        _liquidationStrategy = strategy;
        emit ChangeLiquidationStrategy(strategy);
    }
}