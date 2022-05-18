// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract BnbOracle {

    event PriceTokenChanged(address token);

    AggregatorV3Interface private _priceFeed;
    address private _owner;

    constructor(address bnbUSD) public {
        _owner = msg.sender;
        _priceFeed = AggregatorV3Interface(bnbUSD);
    }

    /**
     * Returns the latest price
     */
    function peek() public view returns (bytes32, bool) {
        (, int256 price, , , ) = _priceFeed.latestRoundData();
        if (price <= 0) {
            return (bytes32(0), false);
        }
        return (bytes32(uint256(price)), true);
    }

    function changePriceToken(address token) external {
        require(msg.sender == _owner, "Forbidden");
        _priceFeed = AggregatorV3Interface(token);
        emit PriceTokenChanged(token);
    }
}