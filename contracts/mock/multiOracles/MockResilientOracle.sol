// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./../../oracle/interfaces/IResilientOracle.sol";

contract MockResilientOracle is IResilientOracle, Initializable, AccessControlUpgradeable {
    IResilientOracle public resilientOracle;

    // token => price
    mapping(address => uint256) public prices;

    function initialize(address _admin, address _resilientOracle) public initializer {
         _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        resilientOracle = IResilientOracle(_resilientOracle);
    }

    function realPrice(address asset) external view returns (uint256) {
        return resilientOracle.peek(asset);
    }

    function syncRealPrice(address asset) external onlyRole(DEFAULT_ADMIN_ROLE) {
        prices[asset] = resilientOracle.peek(asset);
    }

    function setPrice(address asset, uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        prices[asset] = _price;
    }

    function peek(address asset) public view returns (uint256) {
        return prices[asset];
    }
}
