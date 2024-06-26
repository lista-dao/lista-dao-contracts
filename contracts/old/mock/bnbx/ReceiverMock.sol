//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract ReceiverMock {
    receive() external payable {
        for (uint256 i = 0; i <= 100; i++) {
            require(i <= 100, "i > 100, some random require");
        }
    }
}
