// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
  * @title LpUsd
  * @notice This contract is an ERC20 token that represents the liquidity in Usd for a specific collateral via a provider
  */
contract LpUsd is ERC20, Ownable2Step {

  address public minter;
  modifier onlyMinter() {
    require(msg.sender == minter, "LpUsd: caller is not the minter");
    _;
  }
  event MinterChanged(address indexed oldMinter, address indexed newMinter);

  /**
    * @dev Constructor to initialize the token with a name and symbol
    * @param token0 Address of the first token in the pair
    * @param token1 Address of the second token in the pair
    */
  constructor(address token0, address token1)
  ERC20(
    string(abi.encodePacked(IERC20Metadata(token0).symbol() , "/", IERC20Metadata(token1).symbol(), " LPUSD")),
    string(abi.encodePacked(IERC20Metadata(token0).symbol() , "/", IERC20Metadata(token1).symbol(), " LPUSD"))
  )
  {}

  /**
    * @dev Mint tokens to a specific account
    * @param account Address of the account to mint tokens to
    * @param amount Amount of tokens to mint
    */
  function mint(address account, uint256 amount) external onlyMinter {
    _mint(account, amount);
  }

  /**
    * @dev Burn tokens from a specific account
    * @param account Address of the account to burn tokens from
    * @param amount Amount of tokens to burn
    */
  function burn(address account, uint256 amount) external onlyMinter {
    _burn(account, amount);
  }

  /**
    * @dev Set the minter address
    * @param newMinter Address of the new minter
    */
  function setMinter(address newMinter) external onlyOwner {
    require(newMinter != address(0) && newMinter != minter, "LpUsd: new minter is the zero address");
    address oldMinter = minter;
    minter = newMinter;
    emit MinterChanged(oldMinter, newMinter);
  }
}
