// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
  * @title LpUsd
  * @notice This contract is an ERC20 token that represents the liquidity in Usd for a specific collateral via a provider
  */
contract LpUsd is ERC20, Ownable {
  /**
    * @dev Constructor to initialize the token with a name and symbol
    * @param token0Name Name of the first token in the pair
    * @param token1Name Name of the second token in the pair
    */
  constructor(string memory token0Name, string memory token1Name)
  ERC20(
    string(abi.encodePacked(token0Name, "/", token1Name, " LPUSD")),
    string(abi.encodePacked(token0Name, "/", token1Name, " LPUSD"))
  )
  {}

  /**
    * @dev Mint tokens to a specific account
    * @param account Address of the account to mint tokens to
    * @param amount Amount of tokens to mint
    */
  function mint(address account, uint256 amount) external onlyOwner {
    _mint(account, amount);
  }

  /**
    * @dev Burn tokens from a specific account
    * @param account Address of the account to burn tokens from
    * @param amount Amount of tokens to burn
    */
  function burn(address account, uint256 amount) external onlyOwner {
      _burn(account, amount);
  }

}
