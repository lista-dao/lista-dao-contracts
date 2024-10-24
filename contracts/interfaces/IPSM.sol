pragma solidity ^0.8.10;

interface IPSM {
    function buyGem(uint256 amount) external;

    function sellGem(uint256 amount) external;
}