pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EarnPool is OwnableUpgradeable {
    constructor() {
        _disableInitializers();
    }

    /**
      * @dev initialize contract
      * @param _owner owner address
      */
    function initialize(address _owner) public initializer {
        require(_owner != address(0), "owner cannot be zero address");
        __Ownable_init();
        transferOwnership(_owner);
    }
}