// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { yUSDFixedPriceFeed } from "../../../contracts/oracle/priceFeeds/yUSDFixedPriceFeed.sol";

contract yUSDPriceFeedTest is Script {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Interaction implementation
        yUSDFixedPriceFeed feed = new yUSDFixedPriceFeed();
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}
