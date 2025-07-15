// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
  * @title LpUsd
  * @notice This contract is an ERC20 token that represents the liquidity in Usd for a specific collateral via a provider
  */
contract LpUsd is ERC20Upgradeable, Ownable2StepUpgradeable {

  address public minter;
  event MinterChanged(address oldMinter, address newMinter);
  modifier onlyMinter() {
    require(msg.sender == minter, "LpUsd/only-minter");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
    * @dev Initialize the contract with the name, symbol and minter address
    * @param _name Name of the token
    * @param _symbol Symbol of the token
    * @param _minter Address of the minter
    */
  function initialize(string memory _name, string memory _symbol, address _minter) external initializer {
    require(_minter != address(0), "LpUsd/zero-address-minter");
    __Ownable2Step_init();
    __ERC20_init(_name, _symbol);
    minter = _minter;
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
    * @dev Set a new minter address
    * @param _minter Address of the new minter
    */
  function setMinter(address _minter) external onlyOwner {
    require(_minter != address(0) && minter != _minter, "LpUsd/invalid-minter");
    address oldMinter = minter;
    minter = _minter;
    emit MinterChanged(oldMinter, minter);
  }
}
