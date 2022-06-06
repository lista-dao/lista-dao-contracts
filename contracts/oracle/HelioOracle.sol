// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "../interfaces/PipLike.sol";

contract HelioOracle is PipLike {

    event PriceChanged(uint256 newPrice);

    address private _owner;
    uint256 private price;

    constructor(uint256 initialPrice) {
        _owner = msg.sender;
        price = initialPrice;
    }

    /**
     * Returns the latest price
     */
    function peek() public view returns (bytes32, bool) {
        return (bytes32(price), true);
    }

    function changePriceToken(uint256 price_) external {
        require(msg.sender == _owner, "Forbidden");
        price = price_;
        emit PriceChanged(price);
    }
}