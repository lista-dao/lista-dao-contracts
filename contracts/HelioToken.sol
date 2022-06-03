// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract HelioToken is ERC20 {

    event Start(address user);
    event Stop(address user);

    bool public  stopped;

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth {
        require(usr != address(0), "HelioToken/invalid-address");
        wards[usr] = 1;
    }
    function deny(address usr) external auth {
        require(usr != address(0), "HelioToken/invalid-address");
        wards[usr] = 0;
    }
    modifier auth {
        require(wards[msg.sender] == 1, "HelioToken/not-authorized");
        _;
    }

    modifier stoppable {
        require(!stopped, "helio-is-stopped");
        _;
    }

    constructor() ERC20("Helio Reward token", "HELIO"){
        wards[msg.sender] = 1;
    }

    function mint(address _to, uint256 _amount) external auth stoppable returns(bool) {
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) external stoppable returns(bool) {
        _burn(msg.sender, _amount);
        return true;
    }

    function stop() public auth {
        stopped = true;
        emit Stop(msg.sender);
    }

    function start() public auth {
        stopped = false;
        emit Start(msg.sender);
    }
}
