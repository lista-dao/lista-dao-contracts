// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract mBNB is ERC20 {

    address joinContract;

    constructor(address _join) ERC20("Mercury BNB", "mBNB"){
        joinContract = _join;
    }

    function mint(address _to, uint256 _amount) external returns(bool) {
        require(msg.sender == joinContract, "Forbidden");
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) external returns(bool) {
        require(msg.sender == joinContract, "Forbidden");
        _burn(msg.sender, _amount);
        return true;
    }
}
