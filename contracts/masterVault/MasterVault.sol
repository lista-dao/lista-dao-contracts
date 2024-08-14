// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "../ceros/interfaces/ICertToken.sol";
// import "../ceros/interfaces/IWETH.sol";
import "../ceros/interfaces/IBinancePool.sol";
import "./interfaces/IMasterVault.sol";
import "./interfaces/IWaitingPool.sol";
import "../strategy/IBaseStrategy.sol";
contract MasterVault is
IMasterVault,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{
    /**
     * Variables
     */
    struct StrategyParams {
        bool active;
        uint256 allocation;
        uint256 debt;
    }

    mapping (address => StrategyParams) public strategyParams;
    mapping(address => bool) public manager;

    uint256 public depositFee;
    uint256 public maxDepositFee;
    uint256 public withdrawalFee;
    uint256 public maxWithdrawalFee;
    uint256 public feeEarned;
    uint256 public MAX_STRATEGIES;
    uint256 public totalDebt;      // Amount of assets that all strategies have borrowed

    address[] public strategies;
    address public provider;
    address public vaultToken;
    address public asset;
    address payable public feeReceiver;

    IWaitingPool public waitingPool;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event FeeClaimed(address indexed receiver, uint256 amount);
    /**
     * Modifiers
     */
    modifier onlyProvider() {
        require(
            msg.sender == owner() || msg.sender == provider,
            "Provider: not allowed"
        );
        _;
    }
    modifier onlyManager() {
        require(
            manager[msg.sender],
            "Manager: not allowed"
        );
        _;
    }

    /// @dev initialize function - Constructor for Upgradable contract, can be only called once during deployment
    /// @dev Deploys the contract and sets msg.sender as owner
    /// @param maxDepositFees Fees charged in parts per million; 1% = 10000ppm
    /// @param maxWithdrawalFees Fees charged in parts per million; 1% = 10000ppm
    /// @param maxStrategies Number of maximum strategies
    function initialize(
        uint256 maxDepositFees,
        uint256 maxWithdrawalFees,
        uint8 maxStrategies,
        address ceToken
    ) public initializer {
        require(maxDepositFees > 0 && maxDepositFees <= 1e6, "invalid maxDepositFee");
        require(maxWithdrawalFees > 0 && maxWithdrawalFees <= 1e6, "invalid maxWithdrawalFees");

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        manager[msg.sender] = true;
        maxDepositFee = maxDepositFees;
        maxWithdrawalFee = maxWithdrawalFees;
        MAX_STRATEGIES = maxStrategies;
        feeReceiver = payable(msg.sender);
        vaultToken = ceToken;
    }

    /// @dev deposits assets and mints shares(amount - (swapFee + depositFee)) to caller's address
    /// @return shares - number of minted vault tokens
    function depositETH() public
    payable
    override
    nonReentrant
    whenNotPaused
    onlyProvider
    returns (uint256 shares) {
        address src = msg.sender;
        uint256 amount = msg.value;
        require(amount > 0, "invalid amount");
        shares = _assessFee(amount, depositFee);
        feeEarned += amount - shares;
        // shares = _assessDepositFee(shares);
        ICertToken(vaultToken).mint(src, shares);
        emit Deposit(src, src, amount, shares);
    }

    /// @dev burns vault tokens and withdraws(amount - swapFee + withdrawalFee) to callers address
    /// @param account receipient's address
    /// @param amount amount of assets to withdraw
    /// @return shares : amount of assets(excluding fee)
    function withdrawETH(address account, uint256 amount)
    external
    override
    nonReentrant
    whenNotPaused
    onlyProvider
    returns (uint256 shares) {
        address src = msg.sender;
        ICertToken(vaultToken).burn(src, amount);
        uint256 ethBalance = totalAssetInVault();
        shares = _assessFee(amount, withdrawalFee);
        feeEarned += amount - shares;
        if(ethBalance < shares) {
            (bool sent, ) = payable(account).call{value: ethBalance}("");
            require(sent, "transfer failed");
            uint256 withdrawn = withdrawFromActiveStrategies(account, shares - ethBalance);
            require(withdrawn <= shares - ethBalance, "invalid withdrawn amount");
            shares = ethBalance + withdrawn;
        } else {
            (bool sent, ) = payable(account).call{value: shares}("");
            require(sent, "transfer failed");
        }
        emit Withdraw(src, src, src, amount, shares);
        return shares;
    }

    /// @dev attemps withdrawal from the strategies
    /// @param amount assets to withdraw from strategy
    /// @return withdrawn - assets withdrawn from the strategy
    function withdrawFromActiveStrategies(address recipient, uint256 amount) private returns(uint256 withdrawn) {
        for(uint8 i = 0; i < strategies.length; i++) {
            if (strategyParams[strategies[i]].active && strategyParams[strategies[i]].debt > 0 && withdrawn < amount) {
                if (strategyParams[strategies[i]].debt >= amount - withdrawn) {
                    withdrawn += _withdrawFromStrategy(strategies[i], recipient, amount - withdrawn);
                    return withdrawn;
                }
                else {
                    withdrawn += _withdrawFromStrategy(strategies[i], recipient, strategyParams[strategies[i]].debt);
                }
            }
        }
        return withdrawn;
    }

    /// @dev internal method to deposit assets into the given strategy
    /// @param strategy address of the strategy
    /// @param amount assets to deposit into strategy
    function _depositToStrategy(address strategy, uint256 amount) private returns (bool success){
        require(amount > 0, "invalid deposit amount");
        require(totalAssetInVault() >= amount, "insufficient balance");
        if (strategyParams[strategy].active && IBaseStrategy(strategy).canDeposit(amount)) {
            uint256 value = IBaseStrategy(strategy).deposit{value: amount}();
            if(value > 0) {
                totalDebt += value;
                strategyParams[strategy].debt += value;
                emit DepositedToStrategy(strategy, amount);
                return true;
            }
        }
    }

    // function _updateCerosStrategyDebt(address strategy, uint256 amount) external onlyOwner {
    //     totalDebt = amount;
    //     strategyParams[strategy].debt = amount;
    // }

    /// @dev deposits all the assets into the given strategy
    /// @param strategy address of the strategy
    function depositAllToStrategy(address strategy) public onlyManager {
        uint256 amount = totalAssetInVault();
        require(_depositToStrategy(strategy, amount));
    }
    /// @dev deposits specific amount of assets into the given strategy
    /// @param strategy address of the strategy
    /// @param amount assets to deposit into strategy
    function depositToStrategy(address strategy, uint256 amount) public onlyManager {
        require(_depositToStrategy(strategy, amount));
    }

    /// @dev withdraw specific amount of assets from the given strategy
    /// @param strategy address of the strategy
    /// @param amount assets to withdraw from the strategy
    function withdrawFromStrategy(address strategy, uint256 amount) public onlyManager {
        _withdrawFromStrategy(strategy, address(this), amount);
    }

    /// @dev withdraw strategy's total debt
    /// @param strategy address of the strategy
    function withdrawAllFromStrategy(address strategy) external onlyManager {
        _withdrawFromStrategy(strategy, address(this), strategyParams[strategy].debt);
    }

    /// @dev internal function to withdraw specific amount of assets from the given strategy
    /// @param strategy address of the strategy
    /// @param amount assets to withdraw from the strategy
    /// NOTE: subtracts the given amount of assets instead of value(withdrawn funds) because
    ///       of the swapFee that is deducted in the binancePool contract and that fee needs
    ///       to be paid by the users only
    function _withdrawFromStrategy(address strategy, address recipient, uint256 amount) private returns(uint256) {
        require(amount > 0, "invalid withdrawal amount");
        require(strategyParams[strategy].debt >= amount, "insufficient assets in strategy");
        uint256 value = IBaseStrategy(strategy).withdraw(recipient, amount);
        require(
            value <= amount,
            "invalid withdrawn amount"
        );
        totalDebt -= amount;
        strategyParams[strategy].debt -= amount;
        emit WithdrawnFromStrategy(strategy, amount);
        return value;
    }

    /// @dev withdraw specific amount of assets from the given strategy, will get (aBNBc/stkBNB/snBNB/BNBx)
    /// @param strategy address of the strategy
    /// @param amount assets to withdrawInToken from the strategy
    function withdrawInTokenFromStrategy(address strategy, address recipient, uint256 amount)
    external
    override
    nonReentrant
    whenNotPaused
    onlyProvider returns(uint256) {
        require(amount > 0, "invalid withdrawal amount");
        require(strategyParams[strategy].debt >= amount, "insufficient assets in strategy");
        address src = msg.sender;
        ICertToken(vaultToken).burn(src, amount);
        if (withdrawalFee > 0) {
            uint256 shares = _assessFee(amount, withdrawalFee);
            _withdrawInTokenFromStrategy(strategy, feeReceiver, amount - shares);
            return _withdrawInTokenFromStrategy(strategy, recipient, shares);
        }
        return _withdrawInTokenFromStrategy(strategy, recipient, amount);
    }

    /// @dev internal function to withdraw specific amount of assets from the given strategy,
    ///    will get (aBNBc/stkBNB/snBNB/BNBx)
    /// @param strategy address of the strategy
    /// @param amount assets to withdraw from the strategy
    function _withdrawInTokenFromStrategy(address strategy, address recipient, uint256 amount) private returns(uint256) {
        uint256 value = IBaseStrategy(strategy).withdrawInToken(recipient, amount);
        totalDebt -= amount;
        strategyParams[strategy].debt -= amount;
        emit WithdrawnInTokenFromStrategy(strategy, amount);
        return value;
    }

    //estimate how much token(aBNBc/stkBNB/snBNB/BNBx) can get when do withdrawInToken
    function estimateInTokenFromStrategy(address strategy, uint256 amount) external view returns(uint256) {
        return IBaseStrategy(strategy).estimateInToken(amount);
    }
    // calculate the total(aBNBc/stkBNB/snBNB/BNBx) in the strategy contract
    function balanceOfTokenFromStrategy(address strategy) external view returns(uint256) {
        return IBaseStrategy(strategy).balanceOfToken();
    }

    /// @dev sets new strategy
    /// @param strategy address of the strategy
    /// @param allocation percentage of total assets available in the contract
    ///                   that needs to be allocated to the given strategy
    function setStrategy(
        address strategy,
        uint256 allocation   // 1% = 10000
    ) external onlyOwner {
        require(strategy != address(0));
        require(strategies.length < MAX_STRATEGIES, "max strategies exceeded");
        require(address(IBaseStrategy(strategy).vault()) == address(this), "invalid strategy");
        uint256 totalAllocations;
        for(uint256 i = 0; i < strategies.length; i++) {
            if(strategies[i] == strategy) {
                revert("strategy already exists");
            }
            if(strategyParams[strategies[i]].active) {
                totalAllocations += strategyParams[strategies[i]].allocation;
            }
        }

        require(totalAllocations + allocation <= 1e6, "allocations cannot be more than 100%");

        StrategyParams memory params = StrategyParams({
            active: true,
            allocation: allocation,
            debt: 0
        });

        strategyParams[strategy] = params;
        strategies.push(strategy);
        emit StrategyAdded(strategy, allocation);
    }

    /// @dev withdraws all the assets from the strategy and marks it inactive
    /// @param strategy address of the strategy
    /// NOTE: To avoid any unforeseen issues because of solidity divisions
    ///       and always be able to deactivate a strategy,
    ///       it withdraws strategy's (debt - 10) assets and set debt to 0.
    function retireStrat(address strategy) external onlyManager {
        // require(strategyParams[strategy].active, "strategy is not active");
        if(_deactivateStrategy(strategy)) {
            return;
        }
        _withdrawFromStrategy(strategy, address(this), strategyParams[strategy].debt);
        _deactivateStrategy(strategy);
    }

    // /// @dev internal function to check strategy's debt and deactive it.
    // /// @param strategy address of the strategy
    function _deactivateStrategy(address strategy) private returns(bool success) {
        if (strategyParams[strategy].debt <= 10) {
            strategyParams[strategy].active = false;
            strategyParams[strategy].debt = 0;
            return true;
        }
    }

    /// @dev Tries to allocate funds to strategies based on their allocations.
    /// NOTE: OnlyManager can trigger this function
    ///      (It will be triggered mostly in case of deposits)
    function allocate() public onlyManager {
        for(uint8 i = 0; i < strategies.length; i++) {
            if(strategyParams[strategies[i]].active) {
                StrategyParams memory strategy =  strategyParams[strategies[i]];
                uint256 allocation = strategy.allocation;
                if(allocation > 0) {
                    uint256 totalAssetAndDebt = totalAssetInVault() + totalDebt;
                    uint256 strategyRatio = (strategy.debt * 1e6) / totalAssetAndDebt;
                    if(strategyRatio < allocation) {
                        uint256 depositAmount = ((totalAssetAndDebt * allocation) / 1e6) - strategy.debt;
                        if(totalAssetInVault() >= depositAmount) {
                            _depositToStrategy(strategies[i], depositAmount);
                        }
                    }
                }
            }
        }
    }

    function _isValidAllocation() private view returns(bool) {
        uint256 totalAllocations;
        for(uint256 i = 0; i < strategies.length; i++) {
            if(strategyParams[strategies[i]].active) {
                totalAllocations += strategyParams[strategies[i]].allocation;
            }
        }

        return totalAllocations <= 1e6;
    }

    /// @dev Returns the amount of assets that can be withdrawn instantly
    function availableToWithdraw() public view returns(uint256 available) {
        for(uint8 i = 0; i < strategies.length; i++) {
            available += strategies[i].balance;   // excluding the amount that is deposited to strategies
        }
        available += totalAssetInVault();
    }

    function totalAssets() public view returns (uint256) {
        return address(this).balance;
    }

    /// @dev Returns the amount of assets present in the contract(assetBalance - feeEarned)
    function totalAssetInVault() public view returns(uint256 balance) {
        return (totalAssets() > feeEarned) ? totalAssets() - feeEarned : 0;
    }

    /// @dev migrates strategy contract - withdraws everything from the oldStrategy and
    ///      overwrites it with new strategy
    /// @param oldStrategy address of the old strategy
    /// @param newStrategy address of the new strategy
    /// @param newAllocation percentage of total assets available in the contract
    ///                      that needs to be allocated to the new strategy
    function migrateStrategy(address oldStrategy, address newStrategy, uint256 newAllocation) external onlyManager {
        require(oldStrategy != address(0));
        require(newStrategy != address(0));

        uint256 oldStrategyDebt = strategyParams[oldStrategy].debt;

        if(oldStrategyDebt > 0) {
            uint256 withdrawn = _withdrawFromStrategy(oldStrategy, address(this), strategyParams[oldStrategy].debt);
            require(withdrawn > 0, "cannot withdraw from strategy");
        }
        StrategyParams memory params = StrategyParams({
            active: true,
            allocation: newAllocation,
            debt: 0
        });
        bool isValidStrategy;
        for(uint256 i = 0; i < strategies.length; i++) {
            if(strategies[i] == oldStrategy) {
                isValidStrategy = true;
                strategies[i] = newStrategy;
                strategyParams[newStrategy] = params;

                break;
            }
        }
        require(isValidStrategy, "invalid oldStrategy address");
        require(_isValidAllocation(), "allocations cannot be more than 100%");
        emit StrategyMigrated(oldStrategy, newStrategy, newAllocation);
    }

    /// @dev deducts the fee percentage from the given amount
    /// @param amount amount to deduct fee from
    /// @param fees fee percentage
    function _assessFee(uint256 amount, uint256 fees) private pure returns(uint256 value) {
        if(fees > 0) {
            uint256 fee = (amount * fees) / 1e6;
            value = amount - fee;
        } else {
            return amount;
        }
    }

    receive() external payable {}

    /**
     * PAUSABLE FUNCTIONALITY
     */
    function pause() external onlyOwner {
        _pause();
    }
    function unPause() external onlyOwner {
        _unpause();
    }

    /// @dev only owner can call this function to withdraw earned fees
    function withdrawFee() external nonReentrant onlyManager {
        if(feeEarned > 0 && totalAssets() >= feeEarned) {
            (bool sent, ) = payable(feeReceiver).call{value: feeEarned}("");
            require(sent, "transfer failed");
            feeEarned = 0;
            emit FeeClaimed(feeReceiver, feeEarned);
        }
    }

    /// @dev only owner can set new deposit fee
    /// @param newDepositFee new deposit fee percentage
    function setDepositFee(uint256 newDepositFee) external onlyOwner {
        require(maxDepositFee > newDepositFee,"more than maxDepositFee");
        depositFee = newDepositFee;    // 1% = 10000ppm
        emit DepositFeeChanged(newDepositFee);
    }

    /// @dev only owner can set new withdrawal fee
    /// @param newWithdrawalFee new withdrawal fee percentage
    function setWithdrawalFee(uint256 newWithdrawalFee) external onlyOwner {
        require(maxWithdrawalFee > newWithdrawalFee,"more than maxWithdrawalFee");
        withdrawalFee = newWithdrawalFee;
        emit WithdrawalFeeChanged(newWithdrawalFee);
    }

    /// @dev only owner can add new manager
    /// @param newManager new manager address
    function addManager(address newManager) external onlyOwner {
        require(newManager != address(0));
        manager[newManager] = true;
        emit ManagerAdded(newManager);
    }

    /// @dev only owner can remove manager
    /// @param _manager manager address
    function removeManager(address _manager) external onlyOwner {
        require(manager[_manager]);
        manager[_manager] = false;
        emit ManagerRemoved(_manager);
    }

    /// @dev only owner can change provider address
    /// @param newProvider new provider address
    function changeProvider(address newProvider) external onlyOwner {
        require(newProvider != address(0));
        provider = newProvider;
        emit ProviderChanged(provider);
    }

    /// @dev only owner can change fee receiver address
    /// @param _feeReceiver new fee receiver address
    function changeFeeReceiver(address payable _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0));
        feeReceiver = _feeReceiver;
        emit FeeReceiverChanged(_feeReceiver);
    }

    /// @dev only owner can change strategy's allocation
    /// @param strategy strategy address
    /// @param allocation new allocation - percentage of total assets available in the contract
    ///                   that needs to be allocated to the new strategy
    function changeStrategyAllocation(address strategy, uint256 allocation) external onlyOwner {
        require(strategy != address(0));
        strategyParams[strategy].allocation = allocation;
        require(_isValidAllocation(), "allocations cannot be more than 100%");

        emit StrategyAllocationChanged(strategy, allocation);
    }
}

