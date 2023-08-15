// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IBETH is IERC20 {
    function deposit(uint256 amount, address referral) external;
    
    function exchangeRate() external view returns (uint256);
}
