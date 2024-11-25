// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPSM {
    function buy(uint256 amount) external;

    function sell(uint256 amount) external;

    function token() external view returns (address);
}