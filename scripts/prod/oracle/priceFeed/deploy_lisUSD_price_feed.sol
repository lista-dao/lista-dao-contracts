// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { lisUSDPriceFeed } from "../../../../contracts/oracle/priceFeeds/lisUSDPriceFeed.sol";

contract lisUSDPriceFeedDeploy is Script {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy lisUSD price feed
        lisUSDPriceFeed feed = new lisUSDPriceFeed();
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}
