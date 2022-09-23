// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MintableERC20 is ERC20 {
  // solhint-disable-next-line no-empty-blocks
  constructor() ERC20("TEST_ERC20", "TST") {}

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }

  function mintMe(uint256 amount) external {
    _mint(msg.sender, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }

  function burnMe(uint256 amount) external {
    _burn(msg.sender, amount);
  }
}
