// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        uint256 initialSupply = 1e18 * 1e9;
        _mint(msg.sender, initialSupply);
    }
}