// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/PipLike.sol";

contract HelioOracle is PipLike, Initializable, UUPSUpgradeable, OwnableUpgradeable  {

    event PriceChanged(uint256 newPrice);

    address private _owner;
    uint256 private price;

    // --- Init ---
    function initialize(uint256 initialPrice) public initializer {
        __Ownable_init();

        price = initialPrice;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * Returns the latest price
     */
    function peek() public view returns (bytes32, bool) {
        return (bytes32(price), true);
    }

    function changePriceToken(uint256 price_) external {
        require(msg.sender == _owner, "HelioOracle/forbidden");
        price = price_;
        emit PriceChanged(price);
    }
}