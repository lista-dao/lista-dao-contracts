// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ERC20ModUpgradeable.sol";

contract wBNB is OwnableUpgradeable, ERC20ModUpgradeable {
    function initialize() public initializer {
        __Ownable_init();
        __ERC20_init_unchained("Ankr BNB Reward Bearing Certificate", "aBNBc");
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function deposit() public payable {
        _balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 wad) public {
        require(_balances[msg.sender] >= wad, "");
        _balances[msg.sender] -= wad;
        address payable wallet = payable(msg.sender);
        wallet.transfer(wad);
    }
}
