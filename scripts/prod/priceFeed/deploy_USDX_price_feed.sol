// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { USDXLiquidationPriceFeed } from "../../../contracts/oracle/priceFeeds/USDXLiquidationPriceFeed.sol";

contract USD1PriceFeedDeploy is Script {
    uint256 price = 865 * 1e5;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Interaction sUSD1_USD1_PriceFeed
        USDXLiquidationPriceFeed feed = new USDXLiquidationPriceFeed(price);
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}

