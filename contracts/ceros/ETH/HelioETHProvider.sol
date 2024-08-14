// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IDao.sol";
import "../interfaces/ICerosETHRouter.sol";
import "../interfaces/IHelioETHProvider.sol";
import "../interfaces/ICertToken.sol";

contract HelioETHProvider is
IHelioETHProvider,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{
    /**
     * Variables
     */
    address public _operator;
    // Tokens
    address public _certToken; // ETH
    address public _ceToken; //cewBETH
    ICertToken public _collateralToken; // (default hETH)
    ICerosETHRouter public _ceETHRouter;
    IDao public _dao;
    address public _proxy;
    uint256 _minWithdrawalAmount;
    address public _feeReceiver;

    using SafeERC20 for IERC20;
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
    modifier onlyProxy() {
        require(
            msg.sender == owner() || msg.sender == _proxy,
            "AuctionProxy: not allowed"
        );
        _;
    }
    function initialize(
        address collateralToken,
        address certToken,
        address ceToken,
        address ceRouter,
        address daoAddress,
        address feeReceiver,
        uint256 minAmount
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _operator = msg.sender;
        _collateralToken = ICertToken(collateralToken);
        _certToken = certToken;
        _ceToken = ceToken;
        _ceETHRouter = ICerosETHRouter(ceRouter);
        _dao = IDao(daoAddress);
        _minWithdrawalAmount = minAmount;
        _feeReceiver = feeReceiver;
        IERC20(_ceToken).safeApprove(daoAddress, type(uint256).max);
        IERC20(_certToken).safeApprove(ceRouter, type(uint256).max);
    }
    /**
     * DEPOSIT
     */
    function provideInETH(uint256 amount)
    external
    override
    whenNotPaused
    nonReentrant
    returns (uint256 value)
    {
        IERC20(_certToken).safeTransferFrom(msg.sender, address(this), amount);
        value = _ceETHRouter.deposit(amount);
        // deposit ceToken as collateral
        _provideCollateral(msg.sender, value);
        emit Deposit(msg.sender, value);
        return value;
    }
    /**
     * CLAIM
     */
    // claim in wBETH, if the balance is not enough, in ETH
    function claim()
    external
    override
    nonReentrant
    onlyOperator
    returns (uint256 yields)
    {
        yields = _ceETHRouter.claim(_feeReceiver);
        emit Claim(_feeReceiver, yields);
        return yields;
    }
    /**
     * RELEASE
     */
    /// @param amount in ETH
    function releaseInBETH(address recipient, uint256 amount)
    external
    override
    whenNotPaused
    nonReentrant
    returns (uint256 value)
    {
        require(amount >= _minWithdrawalAmount, "Too small withdrawal amount");
        _withdrawCollateral(msg.sender, amount);
        value = _ceETHRouter.withdrawBETH(recipient, amount);
        emit Withdrawal(msg.sender, recipient, value);
        return value;
    }
    function releaseInETH(address recipient, uint256 amount)
    external
    override
    whenNotPaused
    nonReentrant
    returns (uint256 value)
    {
        require(amount >= _minWithdrawalAmount, "Too small withdrawal amount");
        _withdrawCollateral(msg.sender, amount);
        value = _ceETHRouter.withdrawETH(recipient, amount);
        emit Withdrawal(msg.sender, recipient, value);
        return value;
    }
    /**
     * DAO FUNCTIONALITY
     */
    // withdraw collateral to recipient
    /// @param recipient the address to receive liquidated collateral
    /// @param amount in ETH
    /// @dev if ETH amount is not enough, it will send in wBETH
    function liquidation(address recipient, uint256 amount)
    external
    override
    onlyProxy
    nonReentrant
    {
        _ceETHRouter.liquidation(recipient, amount);
    }
    function daoBurn(address account, uint256 value)
    external
    override
    onlyProxy
    nonReentrant
    {
        _collateralToken.burn(account, value);
    }
    function daoMint(address account, uint256 value)
    external
    override
    onlyProxy
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
        IERC20(_ceToken).safeApprove(address(_dao), 0);
        _dao = IDao(dao);
        IERC20(_ceToken).safeApprove(address(_dao), type(uint256).max);
        emit ChangeDao(dao);
    }
    function changeCeToken(address ceToken) external onlyOwner {
        IERC20(_ceToken).safeApprove(address(_dao), 0);
        _ceToken = ceToken;
        IERC20(_ceToken).safeApprove(address(_dao), type(uint256).max);
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
    function changeOperator(address operator) external onlyOwner {
        _operator = operator;
        emit ChangeOperator(operator);
    }
    function changeCertToken(address token) external onlyOwner {
        IERC20(_certToken).safeApprove(address(_ceETHRouter), 0);
        _certToken = token;
        IERC20(_certToken).safeApprove(address(_ceETHRouter), type(uint256).max);
        emit ChangeCertToken(token);
    }
    function changeMinWithdrwalAmount(uint256 amount) external onlyOwner {
        _minWithdrawalAmount = amount;
        emit ChangeWithdrwalAmount(amount);
    }
    /// @dev only owner can change fee receiver address
    /// @param feeReceiver new fee receiver address
    function changeFeeReceiver(address feeReceiver) external onlyOwner {
        require(feeReceiver != address(0) && _feeReceiver != feeReceiver , "feeReceiver must be non-zero or different from the current one");
        _feeReceiver = feeReceiver;
        emit FeeReceiverChanged(_feeReceiver);
    }
}
