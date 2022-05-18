// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract HelioOracle {

    event PriceChanged(uint256 newPrice);

    address private _owner;
    uint256 private price;

    constructor(uint256 initialPrice) public {
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