//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract SnBnbMock is ERC20Upgradeable {
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
