// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "../NonTransferableERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract clisETH is OwnableUpgradeable, NonTransferableERC20 {
    /**
     * Variables
     */

    address private _minter;

    /**
     * Events
     */

    event MinterChanged(address minter);

    /**
     * Modifiers
     */

    modifier onlyMinter() {
        require(msg.sender == _minter, "Minter: not allowed");
        _;
    }

    function initialize() external initializer {
        __Ownable_init();
        __ERC20_init_unchained("Lista Collateral ETH", "clisETH");
    }

    function setName(string memory newName) external onlyOwner {
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked(newName)), "new name cannot be the same as the current name");
        _name = newName;
    }

    function setSymbol(string memory newSymbol) external onlyOwner {
        require(keccak256(abi.encodePacked(_symbol)) != keccak256(abi.encodePacked(newSymbol)), "new symbol cannot be the same as the current symbol");
        _symbol = newSymbol;
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
}
