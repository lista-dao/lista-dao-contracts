//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseStrategy.sol";
import "../stkBNB/interfaces/IAddressStore.sol";
import "../stkBNB/interfaces/IStakedBNBToken.sol";
import "../stkBNB/interfaces/IStakePool.sol";
import "../stkBNB/ExchangeRate.sol";

contract StkBnbStrategy is BaseStrategy {

    using ExchangeRate for ExchangeRate.Data;

    /**
     * @dev The Address Store. Used to fetch addresses of all the other contracts in the stkBNB ecosystem.
     * It is sort of like a router.
     */
    IAddressStore private _addressStore;

    /**
     * @dev The net amount of BNB deposited to StakePool via this strategy.
     * i.e., the amount deposited - the amount withdrawn.
     * This isn't supposed to include the harvest generated from the pool.
     */
    uint256 private _bnbDepositsInStakePool;

    /**
     * @dev the amount of BNB held by this strategy that needs to be distributed back to the users after withdrawal.
     */
    uint256 internal _bnbToDistribute;

    struct WithdrawRequest {
        address recipient;
        uint256 amount;
    }

    /**
     * @dev for bookkeeping the withdrawals initiated from this strategy so that they can later be claimed.
     * This mapping always contains reqs between [_startIndex, _endIndex).
     */
    mapping(uint256 => WithdrawRequest) public withdrawReqs;
    uint256 internal _startIndex;
    uint256 internal _endIndex;

    /**
     * @dev for storing the withdraw requests that can't be fulfilled via the automated mechanism because of gas limits
     * and have to be manually distributed. It stores the sum of all such requests for a recipient.
     */
    mapping(address => uint256) public manualWithdrawAmount;

    event AddressStoreChanged(address addressStore);

    /// @dev initialize function - Constructor for Upgradable contract, can be only called once during deployment
    /// @param destination For our case, its the address of AddressStore contract, as that is constant by design not StakePool.
    /// @param rewards The address to which strategy earnings are transferred
    /// @param masterVault Address of the master vault contract
    /// @param addressStore The contract which holds all the other contract addresses in the stkBNB ecosystem.
    function initialize(
        address destination, // we will never use this in our impl, its there only for legacy purposes.
        address rewards,
        address masterVault,
        address addressStore
    ) public initializer {
        __BaseStrategy_init(destination, rewards, masterVault);

        _addressStore = IAddressStore(addressStore);
    }

    /// @dev to receive withdrawn funds back from StakePool
    receive() external payable override {
        require(
            msg.sender == _addressStore.getStakePool() ||
            msg.sender == strategist,
            "invalid sender"
        );
    }

    // to deposit funds to a destination contract
    function deposit() payable onlyVault external returns (uint256) {
        return _deposit(msg.value);
    }

    // to deposit this contract's existing balance to destination
    function depositAll() onlyStrategist external {
        _deposit(address(this).balance - _bnbToDistribute);
    }

    /// @dev internal function to deposit the given amount of BNB tokens into stakePool
    /// @param amount amount of BNB to deposit
    /// @return amount of BNB that this strategy owes to the master vault
    function _deposit(uint256 amount) whenDepositNotPaused internal returns (uint256) {
        IStakePool stakePool = IStakePool(_addressStore.getStakePool());
        // we don't accept dust, so just remove that. That will keep accumulating in this strategy contract, and later
        // can be deposited via `depositAll` (if it sums up to be more than just dust) OR withdrawn.
        uint256 dust = amount % stakePool.config().minBNBDeposit;
        uint256 dustFreeAmount = amount - dust;
        if (canDeposit(dustFreeAmount)) {
            stakePool.deposit{value : dustFreeAmount}(); // deposit the amount to stakePool in the name of this strategy
            uint256 amountDeposited = assessDepositFee(dustFreeAmount);
            _bnbDepositsInStakePool += amountDeposited; // keep track of _netDeposits in StakePool

            // add dust as that is still owed to the master vault
            return amountDeposited + dust;
        }

        // the amount was so small that it couldn't be deposited to destination but it would remain with this strategy,
        // => strategy still owes this to the master vault
        return amount;
    }

    // to withdraw funds from the destination contract
    function withdraw(address recipient, uint256 amount) onlyVault external returns (uint256) {
        return _withdraw(recipient, amount);
    }

    // withdraw all funds from the destination contract
    function panic() onlyStrategist external returns (uint256) {
        (,, uint256 debt) = vault.strategyParams(address(this));
        return _withdraw(address(vault), debt);
    }

    /// @dev internal function to withdraw the given amount of BNB from StakePool and transfer to masterVault
    /// @param amount amount of BNB to withdraw
    /// @return value - returns the amount of BNB withdrawn and sent back (or will be sent in future) to MasterVault
    function _withdraw(address recipient, uint256 amount) internal returns (uint256) {
        require(amount > 0, "invalid amount");

        uint256 ethBalance = address(this).balance;
        if (amount <= ethBalance) {
            (bool sent, /*memory data*/) = recipient.call{ gas: 5000, value: amount }("");
            require(sent, "!sent");
            return amount;
        }

        // otherwise, need to send all the balance of this strategy and also need to withdraw from the StakePool
        (bool sent, /*memory data*/) = recipient.call{ gas: 5000, value: ethBalance }("");
        require(sent, "!sent");
        amount -= ethBalance;

        // TODO(pSTAKE):
        // 1. There should be a utility function in our StakePool that should tell how much stkBNB to withdraw if I want
        //    `x` amount of BNB back, taking care of the withdrawal fee that is involved.
        // 2. We should also have something that takes care of withdrawing to a recipient, and not to the msg.sender
        // For now, the implementation here works, but can be improved in future with above two points.
        IStakePool stakePool = IStakePool(_addressStore.getStakePool());
        IStakedBNBToken stkBNB = IStakedBNBToken(_addressStore.getStkBNB());

        // reverse the BNB amount calculation from StakePool to get the stkBNB to burn
        ExchangeRate.Data memory exchangeRate = stakePool.exchangeRate();
        uint256 poolTokensToBurn = exchangeRate._calcPoolTokensForDeposit(amount);
        uint256 poolTokens = (poolTokensToBurn * 1e11) / (1e11 - stakePool.config().fee.withdraw);
        // poolTokens = the amount of stkBNB that needs to be sent to StakePool in order to get back `amount` BNB.

        // now, ensure that these poolTokens pass the minimum requirements for withdrawals set in StakePool.
        // if poolTokens < min => StakePool will reject this withdrawal with a revert => okay to let this condition be handled by StakePool.
        // if poolTokens have dust => we can remove that dust here, so that withdraw can happen if the poolTokens > min.
        poolTokens = poolTokens - (poolTokens % stakePool.config().minTokenWithdrawal);

        // now, this amount of poolTokens might not give us exactly the `amount` BNB we wanted to withdraw. So, better
        // calculate that again as we need to return the BNB amount that would actually get withdrawn.
        uint256 poolTokensFee = (poolTokens * stakePool.config().fee.withdraw) / 1e11;
        uint256 value = exchangeRate._calcWeiWithdrawAmount(poolTokens - poolTokensFee);
        require(value <= amount, "invalid out amount");

        // initiate withdrawal of stkBNB from StakePool for this strategy
        // this assumes that this strategy holds at least the amount of stkBNB poolTokens that we are trying to withdraw,
        // otherwise it will revert.
        stkBNB.send(address(stakePool), poolTokens, "");

        // save it so that we can later dispatch the amount to the recipient on claim
        withdrawReqs[_endIndex++] = WithdrawRequest(recipient, value);

        // keep track of _netDeposits in StakePool
        _bnbDepositsInStakePool -= value;

        return value + ethBalance;
    }

    /// @dev Handy function to both claim the funds from StakePool and distribute it to the users in one go.
    /// Might result in out of gas issue, if there are too many withdrawals.
    function claimAndDistribute() external {
        claimAll();
        distribute(_endIndex);
    }

    /// @dev Call this manually to actually get the unstaked BNB back from StakePool after 15 days of withdraw.
    /// Claims all the claimable withdraw requests from StakePool. Ignores non-claimable requests.
    function claimAll() nonReentrant public {
        uint256 prevBalance = address(this).balance;
        // this can result in out of gas, if there have been too many withdraw requests from this Strategy
        IStakePool(_addressStore.getStakePool()).claimAll();

        _bnbToDistribute += address(this).balance - prevBalance;
    }

    // claims a single request from StakePool if it was claimable, i.e., has passed cooldown period of 15 days, reverts otherwise.
    // to be used as a failsafe, in case claimAll() gives out-of-gas issues.
    // You have to know the right index for this call to succeed.
    function claim(uint256 index) nonReentrant external {
        uint256 prevBalance = address(this).balance;
        IStakePool(_addressStore.getStakePool()).claim(index);
        _bnbToDistribute += address(this).balance - prevBalance;
    }

    /// @dev Anybody can call this, it will always distribute the amount to the original recipients to whom the withdraw was intended.
    /// @param endIdx the index (exclusive) till which to distribute the funds for withdraw requests
    function distribute(uint256 endIdx) nonReentrant public {
        require(endIdx <= _endIndex, "endIdx out of bound");

        // dispatch the amount in order of _withdrawReqs
        while (_bnbToDistribute > 0 && _startIndex < endIdx) {
            address recipient = withdrawReqs[_startIndex].recipient;
            uint256 amount = withdrawReqs[_startIndex].amount;
            bool isPartial = false;
            if (amount > _bnbToDistribute) {
                // reqs is getting partially fulfilled
                amount = _bnbToDistribute;
                isPartial = true;
            }

            // try sending the amount to recipient
            (bool sent, /*memory data*/) = recipient.call{ gas: 5000, value: amount }("");
            if (sent) {
                if (isPartial) {
                    // reqs is getting partially fulfilled
                    withdrawReqs[_startIndex].amount -= amount;
                } else {
                    // reqs is getting completely fulfilled. Delete it, and go to next index.
                    delete withdrawReqs[_startIndex++];
                }
                _bnbToDistribute -= amount;
            } else {
                // the recipient didn't accept direct funds within the specified gas, so save the whole request to be
                // withdrawn by the recipient manually later, and remove it from the automated flow.
                manualWithdrawAmount[recipient] += withdrawReqs[_startIndex].amount;
                delete withdrawReqs[_startIndex++];
            }
        }
    }

    /// @dev Anybody can call this to manually send the withdrawn funds to a recipient, if the recipient had funds that
    /// need to be manually withdrawn.
    function distributeManual(address recipient) nonReentrant external {
        uint256 amount = manualWithdrawAmount[recipient];
        require(amount > 0, "!distributeManual");

        // do state changes upfront to prevent reentrancy
        _bnbToDistribute -= amount; // so that if there weren't enough bnb to distribute, it would revert here itself
        delete manualWithdrawAmount[recipient];

        (bool sent, /*memory data*/) = recipient.call{ value: amount }("");
        require(sent, "!sent");
    }

    // claim or collect rewards functions
    function harvest() nonReentrant onlyStrategist external {
        uint256 yieldStkBNB = calculateYield();

        // send the yield tokens to the reward address
        IStakedBNBToken(_addressStore.getStkBNB()).send(rewards, yieldStkBNB, "");
    }

    function calculateYield() public view returns (uint256 yieldStkBNB) {
        IStakedBNBToken stkBNB = IStakedBNBToken(_addressStore.getStkBNB());
        uint256 stkBnbBalance = stkBNB.balanceOf(address(this));
        ExchangeRate.Data memory exchangeRate = IStakePool(_addressStore.getStakePool()).exchangeRate();

        uint256 depositsWithYield = exchangeRate._calcWeiWithdrawAmount(stkBnbBalance);
        uint256 yield = depositsWithYield - _bnbDepositsInStakePool;
        yieldStkBNB = exchangeRate._calcPoolTokensForDeposit(yield);
    }

    // calculate the total amount of tokens in the destination contract
    // @return Just the amount of BNB in our Pool deposited from this strategy excluding the generated yield.
    function balanceOfPool() public view override returns (uint256) {
        return _bnbDepositsInStakePool;
    }

    // returns true if assets can be deposited to destination contract
    function canDeposit(uint256 amount) public view returns (bool) {
        // just ensure min check, no need to enforce dust check here.
        // if amount is more than min, then deposit calls will take care of removing dust.
        if (amount < IStakePool(_addressStore.getStakePool()).config().minBNBDeposit) {
            return false;
        }
        return true;
    }

    // In our case, there is no relayer fee we charge as of now. We do charge a deposit fee (0% as of now) in terms of
    // the liquid token.
    //
    // returns the actual deposit amount (amount - depositFee, if any)
    function assessDepositFee(uint256 amount) public view returns (uint256) {
        return amount - (amount * IStakePool(_addressStore.getStakePool()).config().fee.deposit)/1e11;
    }

    // expose startIndex so that it can be used for initiating off-chain requests
    function startIndex() external view returns (uint256) {
        return _startIndex;
    }

    // expose endIndex so that it can be used for initiating off-chain requests
    function endIndex() external view returns (uint256) {
        return _endIndex;
    }

    /// @dev only owner can change addressStore
    /// @param addressStore new addressStore address
    function changeAddressStore(address addressStore) external onlyOwner {
        require(addressStore != address(0));
        _addressStore = IAddressStore(addressStore);
        emit AddressStoreChanged(addressStore);
    }

}
