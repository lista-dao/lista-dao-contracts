// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {NonTransferableERC20} from "./NonTransferableERC20.sol";


contract ClisToken is OwnableUpgradeable, NonTransferableERC20 {
    /**
     * Variables
     */
    mapping(address => bool) public _minters;

    /**
     * Events
     */
    event MinterChanged(address minter, bool isAdd);

    /**
     * Modifiers
     */
    modifier onlyMinter() {
        require(_minters[msg.sender], "Minter: not allowed");
        _;
    }

    function initialize(string memory name, string memory symbol) external initializer {
        __Ownable_init();
        __ERC20_init_unchained(name, symbol);
    }

    function burn(address account, uint256 amount) external onlyMinter {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external onlyMinter {
        _mint(account, amount);
    }

    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "Minter: zero address");
        require(!_minters[minter], "Minter: already a minter");

        _minters[minter] = true;
        emit MinterChanged(minter, true);
    }

    function removeMinter(address minter) external onlyOwner {
        require(minter != address(0), "Minter: zero address");
        require(_minters[minter], "Minter: not a minter");

        delete _minters[minter];
        emit MinterChanged(minter, false);
    }
}
