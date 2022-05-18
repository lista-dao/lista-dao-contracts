// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

interface IDao {
    function deposit(
        address participant,
        address token,
        uint256 dink
    ) external returns (uint256);

    function withdraw(
        address participant,
        address token,
        uint256 dink
    ) external returns (uint256);
}
