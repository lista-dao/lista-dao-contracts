// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IWBETH {
    function exchangeRate() external view returns (uint256);
}
