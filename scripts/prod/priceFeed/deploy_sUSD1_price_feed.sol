// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { sUSD1PriceFeed } from "../../../contracts/oracle/priceFeeds/sUSD1PriceFeed.sol";

contract sUSD1PriceFeedTest is Script {
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address sUSD1_USD1_PriceFeed = 0x08CA3ac4dE41F2791e8A247859d637a8977473D7;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Interaction sUSD1_USD1_PriceFeed
        sUSD1PriceFeed feed = new sUSD1PriceFeed(resilientOracle, sUSD1_USD1_PriceFeed);
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}
