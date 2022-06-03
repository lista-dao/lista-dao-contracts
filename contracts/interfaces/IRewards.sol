// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IRewards {

    event PoolInited(address token, uint256 rate);

    event HelioTokenChanged(address newToken);

    event HelioOracleChanged(address newOracle);

    event RateChanged(address token, uint256 newRate);

    function drop(address token, address usr) external;
}