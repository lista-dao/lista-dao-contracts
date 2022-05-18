// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract aBNBc is ERC20 {

    address public owner;

    constructor(string memory desc, string memory name) ERC20(desc, name){
        owner = msg.sender;
    }

    function mint(address _to, uint256 _amount) external returns(bool) {
        require(msg.sender == owner, "Forbidden");
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) external returns(bool) {
        require(msg.sender == owner, "Forbidden");
        _burn(msg.sender, _amount);
        return true;
    }

    function mintMe(uint256 _amount) external returns(bool) {
        _mint(msg.sender, _amount);
        return true;
    }
}
