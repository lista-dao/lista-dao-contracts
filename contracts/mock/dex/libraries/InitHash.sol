// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "../PancakePair.sol";

contract CalHash {
    function getInitHash() public pure returns (bytes32) {
        bytes memory bytecode = type(PancakePair).creationCode;
        return keccak256(abi.encodePacked(bytecode));
    }
}
