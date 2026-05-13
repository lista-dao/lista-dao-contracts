// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { SyrupUSDTPriceFeed } from "../../../contracts/oracle/priceFeeds/SyrupUSDTPriceFeed.sol";

contract SyrupUSDTPriceFeedTest is Script {
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address syrupUSDT_USDT_PriceFeed = 0xac9962aAb7b8fe63fA3A5065c22D4Dd700B1C658;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Interaction SyrupUSDTPriceFeed
        SyrupUSDTPriceFeed feed = new SyrupUSDTPriceFeed(resilientOracle, syrupUSDT_USDT_PriceFeed);
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}
