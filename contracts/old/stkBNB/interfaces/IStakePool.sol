// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "../ExchangeRate.sol";

//// 1 stkBNB = (totalWei / poolTokenSupply) BNB
//// 1 BNB = (poolTokenSupply / totalWei) stkBNB
//// Over time, stkBNB appreciates in value as compared to BNB.
//struct ExchangeRateData {
//    uint256 totalWei; // total amount of BNB managed by the pool
//    uint256 poolTokenSupply; // total amount of stkBNB managed by the pool
//}

// External protocols (eg: Wombat Exchange) that integrate with us, rely on this interface.
// We must always ensure that StakePool conforms to this interface.
interface IStakePool {
    struct Config {
        // @dev The address of the staking wallet on the BBC chain. It will be used for transferOut transactions.
        // It needs to be correctly converted from a bech32 BBC address to a solidity address.
        address bcStakingWallet;
        // @dev The minimum amount of BNB required to initiate a cross-chain transfer from BSC to BC.
        // This should be at least minStakingAddrBalance + minDelegationAmount.
        // Ideally, this should be set to a value such that the protocol revenue from this value is more than the fee
        // lost on this value for cross-chain transfer/delegation/undelegation/etc.
        // But, finding the ideal value is non-deterministic.
        uint256 minCrossChainTransfer;
        // The timeout for the cross-chain transfer out operation in seconds.
        uint256 transferOutTimeout;
        // @dev The minimum amount of BNB required to make a deposit to the contract.
        uint256 minBNBDeposit;
        // @dev The minimum amount of tokens required to make a withdrawal from the contract.
        uint256 minTokenWithdrawal;
        // @dev The minimum amount of time (in seconds) a user has to wait after unstake to claim their BNB.
        // It would be 15 days on mainnet. 3 days on testnet.
        uint256 cooldownPeriod;
        // @dev The fee distribution to represent different kinds of fee.
        FeeDistribution fee;
    }

    struct FeeDistribution {
        uint256 reward;
        uint256 deposit;
        uint256 withdraw;
    }

    function config() external view returns (Config memory);

    function exchangeRate() external view returns (ExchangeRate.Data memory);

    function deposit() external payable;

    function claimAll() external;

    function claim(uint256 index) external;
}


