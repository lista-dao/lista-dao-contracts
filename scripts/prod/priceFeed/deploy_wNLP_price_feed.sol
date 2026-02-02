// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { wNLPUSDTPriceFeed } from "../../../contracts/oracle/priceFeeds/wNLPUSDTPriceFeed.sol";

contract yUSDPriceFeedTest is Script {
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Interaction implementation
        wNLPUSDTPriceFeed feed = new wNLPUSDTPriceFeed(resilientOracle);
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}
