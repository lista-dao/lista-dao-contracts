// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./../oracle/interfaces/IResilientOracle.sol";

contract MultiOracleMock is AccessControl, Initializable {
    IResilientOracle constant public resilientOracle = IResilientOracle(0x9CCf790F691925fa61b8cB777Cb35a64F5555e53);// dev multi oracle
    address public TOKEN;

    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    function initialize(address deployer) public initializer {
        _setupRole(UPDATER_ROLE, deployer);
    }

    function updateToken(address _token) external {
        require(hasRole(UPDATER_ROLE, msg.sender), "Caller is not an updater");
        TOKEN = _token;
    }

    /**
     * Returns the latest price
     */
    function peek() public view returns (bytes32, bool) {
        if (TOKEN == address(0)) {
            return (0, false);
        }
        uint256 price = resilientOracle.peek(TOKEN);
        if (price <= 0) {
            return (0, false);
        }
        return (bytes32(uint(price) * 1e10), true);
    }
}
