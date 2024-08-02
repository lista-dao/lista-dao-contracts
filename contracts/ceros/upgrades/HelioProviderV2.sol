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
    address public _certToken; // deprecated
    address public _ceToken;
    ICertToken public _collateralToken; // (default clisBNB)
    IMasterVault public _masterVault;
    IDao public _dao;
    IBNBStakingPool public _pool;
    address public _proxy;
    address public _liquidationStrategy;
    // account > delegation { delegateTo, amount }
    mapping(address => Delegation) public _delegation;
    // a multi-sig wallet which can pause the contract in case of emergency
    address public _guardian;

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
    modifier onlyGuardian() {
        require(
            msg.sender == _guardian && _guardian != address(0),
            "not guardian"
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
        _provideCollateral(msg.sender, msg.sender, value);
        emit Deposit(msg.sender, value);
        return value;
    }
    /**
     * DEPOSIT
     * @notice delegateTo will hold the collateralToken
     */
    function provide(address _delegateTo)
    external
    payable
    override
    whenNotPaused
    nonReentrant
    returns (uint256 value)
    {
        require(_delegateTo != address(0), "delegateTo cannot be zero address");
        require(
            _delegation[msg.sender].delegateTo == _delegateTo ||
            _delegation[msg.sender].amount == 0, // first time, clear old delegatee
            "delegatee is differ from the current one"
        );
        value = _masterVault.depositETH{value: msg.value}();
        // deposit ceToken as collateral
        _provideCollateral(msg.sender, _delegateTo, value);
        // save delegatee's info
        Delegation storage delegation = _delegation[msg.sender];
        delegation.delegateTo = _delegateTo;
        delegation.amount += value;

        emit Deposit(msg.sender, value);
        return value;
    }

    /**
     * CHANGE DELEGATEE
     * @notice By burning all the collateral tokens from the
     *         old delegatee and minting the same amount to the new delegatee,
     *         also replace delegateTo address by the new one to perform the change.
     */
    function changeDelegatee(address _newDelegateTo) external override {
        require(_newDelegateTo != address(0), "delegateTo cannot be zero address");
        require(
            _delegation[msg.sender].amount > 0 && _delegation[msg.sender].delegateTo != _newDelegateTo,
            "delegatee must differ from the current one"
        );
        Delegation storage delegation = _delegation[msg.sender];
        address oldDelegateTo = delegation.delegateTo;
        // burn old delegatee's token
        _collateralToken.burn(oldDelegateTo, delegation.amount);
        // mint to new delegatee
        _collateralToken.mint(_newDelegateTo, delegation.amount);
        // change delegation info
        delegation.delegateTo = _newDelegateTo;

        emit ChangeDelegateTo(msg.sender, oldDelegateTo, _newDelegateTo);
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
        _burnCollateralToken(account, value);
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
    function _provideCollateral(address account, address collateralTokenHolder, uint256 amount) internal {
        // all deposit data will be recorded on behalf of `account`
        _dao.deposit(account, address(_ceToken), amount);
        // collateralTokenHolder can be account or delegateTo
        _collateralToken.mint(collateralTokenHolder, amount);
    }
    function _withdrawCollateral(address account, uint256 amount) internal {
        _dao.withdraw(account, address(_ceToken), amount);
        _burnCollateralToken(account, amount);
    }
    /**
     * Burn collateral Token from both delegator and delegateTo
     * @dev burns delegatee's collateralToken first, then delegator's
     */
    function _burnCollateralToken(address account, uint256 amount) internal {
        if(_delegation[account].amount > 0) {
            uint256 delegatedAmount = _delegation[account].amount;
            uint256 delegateeBurn = amount > delegatedAmount ? delegatedAmount : amount;
            // burn delegatee's token
            _collateralToken.burn(_delegation[account].delegateTo, delegateeBurn);
            // update delegated amount
            _delegation[account].amount -= delegateeBurn;
            // burn delegator's token
            if (amount > delegateeBurn) {
                _collateralToken.burn(account, amount - delegateeBurn);
            }
        } else {
            // no delegation, only burn from account
            _collateralToken.burn(account, amount);
        }
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
    function changeGuardian(address newGuardian) external onlyOwner {
        require(
            newGuardian != address(0) && _guardian != newGuardian,
            "guardian cannot be zero address or same as the current one"
        );
        address oldGuardian = _guardian;
        _guardian = newGuardian;
        emit ChangeGuardian(oldGuardian, newGuardian);
    }
}
