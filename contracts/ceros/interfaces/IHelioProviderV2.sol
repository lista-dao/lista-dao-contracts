// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

interface IHelioProviderV2 {
    /**
     * Events
     */

    event Deposit(address indexed account, uint256 amount);

    event Claim(address indexed recipient, uint256 amount);

    event Withdrawal(
        address indexed owner,
        address indexed recipient,
        uint256 amount
    );

    event WithdrawalInToken(
        address indexed owner,
        address indexed recipient,
        uint256 amount
    );

    event ChangeDao(address dao);

    event ChangeCeToken(address ceToken);

    event ChangeCollateralToken(address collateralToken);

    event ChangeProxy(address auctionProxy);

    event ChangeMasterVault(address masterVault);

    event ChangeBNBStakingPool(address pool);

    event ChangeLiquidationStrategy(address strategy);
    /**
     * Deposit
     */

    // in BNB
    function provide() external payable returns (uint256);

    // in aBNBc
    // function provideInABNBc(uint256 amount) external returns (uint256);

    /**
     * Withdrawal
     */

    // BNB
    function release(address recipient, uint256 amount)
    external
    returns (uint256);

    //User will get (aBNBc/stkBNB/snBNB/BNBx) base on strategy
    function releaseInToken(address strategy, address recipient, uint256 amount)
    external
    returns (uint256);

    //Estimate how much token(aBNBc/stkBNB/snBNB/BNBx) can get when do releaseInToken
    function estimateInToken(address strategy, uint256 amount) external view returns(uint256);

    //Calculate the balance(aBNBc/stkBNB/snBNB/BNBx) in the strategy contract
    function balanceOfToken(address strategy) external view returns(uint256);

    /**
     * DAO FUNCTIONALITY
     */

    function liquidation(address recipient, uint256 amount) external;

    function daoBurn(address account, uint256 value) external;

    function daoMint(address account, uint256 value) external;
}