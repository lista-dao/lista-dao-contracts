//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../masterVault/interfaces/IMasterVault.sol";
import "../bnbx/interfaces/IStakeManager.sol";
import "./BaseStrategy.sol";

contract BnbxYieldConverterStrategy is BaseStrategy {

    IERC20Upgradeable private _bnbxToken;
    IStakeManager private _stakeManager; 
    IMasterVault public vault;

    uint256 bnbx_holding_balance;
    uint256 bnb_deposit_balance;

    event StakeManagerChanged(address stakeManager);

    /// @dev initialize function - Constructor for Upgradable contract, can be only called once during deployment
    /// @param destination Address of the bnbx router contract
    /// @param feeRecipient Address of the fee recipient
    /// @param bnbxToken Address of BNBx token
    /// @param masterVault Address of the masterVault contract
    /// @param stakeManager Address of stakeManager contract
    function initialize(
        address destination,
        address feeRecipient,
        address bnbxToken,
        address masterVault,
        address stakeManager
    ) public initializer {
        __BaseStrategy_init(destination, feeRecipient);

        _bnbxRouter = IBnbxRouter(destination);
        _bnbxToken = IBnbxToken(bnbxToken);
        _stakeManager = IStakeManager(stakeManager);
        vault = IMasterVault(masterVault);

        _bnbxToken.approve(stakeManager, type(uint256).max);
    }

    /**
     * Modifiers
     */
    modifier onlyVault() {
        require(msg.sender == address(vault), "!vault");
        _;
    }

    /// @dev deposits the given amount of BNB into Stader stakeManager through bnbxRouter
    function deposit() external payable onlyVault returns(uint256 value) {
        uint256 amount = msg.value;
        require(amount <= address(this).balance, "insufficient balance");
        
        return _deposit(amount);
    }

    /// @dev deposits all the available BNB into Stader stakeManager through bnbxRouter
    function depositAll() external payable onlyVault returns(uint256 value) {
        return _deposit(address(this).balance);
    }

    /// @dev internal function to deposit the given amount of BNB into Stader stakeManager through bnbxRouter
    /// @param amount amount of BNB
    function _deposit(uint256 amount) internal returns (uint256 value) {
        require(!depositPaused, "deposits are paused");
        require(amount > 0, "invalid amount");
        if (canDeposit(amount)) {
            bnb_deposit_balance += amount;
            bnbx_holding_balance += _stakeManager.convertBnbToBnbX(amount);
            _stakeManager.deposit{value: amount}();
        }
    }

    /// @dev withdraws the given amount of BNB from Stader stakeManager and transfers to masterVault
    /// @param amount amount of BNB
    function withdraw(address recipient, uint256 amount) onlyVault external returns(uint256 value) {
        return _withdraw(recipient, amount);
    }

    /// @dev withdraws everything from Stader stakeManager and transfers to masterVault
    function panic() external onlyStrategist returns (uint256 value) {
        (,, uint256 debt) = vault.strategyParams(address(this));
        return _withdraw(address(vault), debt);
    }

    /// @dev internal function to withdraw the given amount of BNB from Stader stakeManager
    ///      and transfers to masterVault
    /// @param amount amount of BNB
    /// @return value - returns the amount of BNB withdrawn from stader
    function _withdraw(address recipient, uint256 amount) internal returns (uint256 value) {
        require(amount > 0, "invalid amount");

        uint256 bnbxAmount = _stakeManager.convertBnbToBnbX(amount);
        
        bnb_deposit_balance -= amount;
        bnbx_holding_balance -= bnbxAmount;
        
        userRequests[recipient].push( UserRequest({
            batchId: nextWithdrawBatchId,
            bnbAmt : amount,
            bnbxAmount,
            triggerTime,
        }));

        // or maybe queue userRequests;
        // userRequests.push( UserRequest({
        //     batchId: nextWithdrawBatchId,
        //     bnbAmt : amount,
        //     bnbxAmount,
        //     triggerTime,
        // }));

        batchWithdrawTotal += bnbxAmount;

        return 0;
    }

    function batchWithdraw(){
        uint256 nextStakeManagerWithdrawId = _stakeManager.nextUndelegateUUID();
        batchRequest[nextWithdrawBatchId] = BatchRequest({
            nextStakeManagerWithdrawId,
            batchWithdrawTotal,
            triggerTime,
            claimTime: 0
        });
        
        _stakeManager.requestWithdraw(batchWithdrawTotal);

        nextWithdrawBatchId++;
        batchWithdrawTotal = 0;
    }

    function batchClaimWithdraw(){ // transfer funds(BNB) from stakeManager to strategy
        batchWithdrawRequests = _stakeManager.getUserWithdrawalRequests();

        for( each batchReqId : batchWithdrawRequests){ // would be max 7 as once per day
            if batchReqId is claimable => claim it;
        }
    }

    function claimFundsforUsers(){
        // iterate over user requests 
        // check if 15 days have passed after user has triggered requestWithdraw
        // 

    }

    receive() external payable {}

    function canDeposit(uint256 amount) public pure returns(bool) {
        return (amount > 0);
    }

    function assessDepositFee(uint256 amount) public pure returns(uint256) {
        return amount;
    }

    /// @dev claims yeild from ceros in BNBx and transfers to feeRecipient
    function harvest() external onlyStrategist {
        _harvestTo(rewards);
    }

    /// @dev internal function to claim yeild from ceros in BNBx and transfer them to desired address
    function _harvestTo(address to) private returns(uint256 yield) {
        yield = _calculateYield();
        if(yield > 0) {
            bnbx_holding_balance -= yield;
            _bnbxToken.transfer(to, yield);
        }
    }

    function _calculateYield() private returns (uint256 yield) {
        uint256 bnbx_eq_amt = _stakeManager.convertBnbToBnbX(bnb_deposit_balance);

        yield = bnbx_holding_balance - bnbx_eq_amt;

        return yield;
    }

    /// @dev only owner can change stakeManager address
    /// @param stakeManager new stakeManager address
    function changeStakeManager(address stakeManager) external onlyOwner {
        require(stakeManager != address(0));
        _bnbxToken.approve(address(_stakeManager), 0);
        _stakeManager = IStakeManager(stakeManager);
        _bnbxToken.approve(address(_stakeManager), type(uint256).max);
        emit StakeManagerChanged(stakeManager);
    }

}
