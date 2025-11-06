// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { sUSDXLiquidationPriceFeed } from "../../../contracts/oracle/priceFeeds/sUSDXLiquidationPriceFeed.sol";

contract sUSD1PriceFeedDeploy is Script {
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    uint256 exchangeRate = 0.932 ether;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Interaction sUSD1_USD1_PriceFeed
        sUSDXLiquidationPriceFeed feed = new sUSDXLiquidationPriceFeed(resilientOracle, exchangeRate);
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}

