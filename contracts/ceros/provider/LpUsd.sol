// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
  * @title LpUsd
  * @notice This contract is an ERC20 token that represents the liquidity in Usd for a specific collateral via a provider
  */
contract LpUsd is OwnableUpgradeable, ERC20Upgradeable {

  address public minter;
  modifier onlyMinter() {
    require(msg.sender == minter, "LpUsd: caller-is-not-the-minter");
    _;
  }
  event MinterChanged(address indexed oldMinter, address indexed newMinter);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
    * @dev initialize the token with a name and symbol
    * @param token0 Address of the first token in the pair
    * @param token1 Address of the second token in the pair
    */
  function initialize(address token0, address token1) public initializer {
    require(token0 != address(0) && token1 != address(0), "LpUsd: zero-address-provided");

    __Ownable_init();
    __ERC20_init_unchained(name(), symbol());

    string memory _nameAndSymbol = string(abi.encodePacked(IERC20MetadataUpgradeable(token0).symbol() , "/", IERC20MetadataUpgradeable(token1).symbol(), " LPUSD"));

    __Ownable_init();
    __ERC20_init_unchained(_nameAndSymbol, _nameAndSymbol);
  }

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
    require(newMinter != address(0) && newMinter != minter, "LpUsd: new minter is invalid");
    address oldMinter = minter;
    minter = newMinter;
    emit MinterChanged(oldMinter, newMinter);
  }
}
