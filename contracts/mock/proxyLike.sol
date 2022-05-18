//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../jug.sol";

interface GemLike {
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
}

interface DaiJoinLike {
    function dai() external returns (GemLike);
    function join(address, uint) external payable;
    function exit(address, uint) external;
}

contract ProxyLike is Ownable {
    uint256 constant RAY = 10 ** 27;
    address jug;
    address vat;
    constructor(address _jug, address _vat) {
        jug = _jug;
        vat = _vat;
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        unchecked {
            require((z = x - y) <= x, "sub-overflow");    
        } 
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        unchecked {
            require(y == 0 || (z = x * y) / y == x, "mul-overflow");
        }
    }

    function jugInitFile(bytes32 _gem, bytes32 _what, uint256 _rate) external onlyOwner {
        Jug(jug).init(_gem);
        Jug(jug).file(_gem, _what, _rate);
    }
}
