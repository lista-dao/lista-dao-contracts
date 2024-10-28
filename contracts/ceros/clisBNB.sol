// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {NonTransferableERC20} from "./NonTransferableERC20.sol";

contract clisBNB is OwnableUpgradeable, NonTransferableERC20 {
    /**
     * Variables
     */
    address private _minter;

    mapping(address => bool) public _minters;

    /**
     * Events
     */
    event MinterChanged(address minter);
    event MinterChanged(address minter, bool isAdd);

    /**
     * Modifiers
     */
    modifier onlyMinter() {
        require(msg.sender == _minter || _minters[msg.sender], "Minter: not allowed");
        _;
    }

    function initialize() external initializer {
        __Ownable_init();
        __ERC20_init_unchained("Lista Collateral BNB", "clisBNB");
    }

    function burn(address account, uint256 amount) external onlyMinter {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external onlyMinter {
        _mint(account, amount);
    }

    function changeMinter(address minter) external onlyOwner {
        _minter = minter;
        emit MinterChanged(minter);
    }

    function getMinter() external view returns (address) {
        return _minter;
    }

    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "Minter: zero address");
        require(minter != _minter, "Minter: already a top minter");
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
