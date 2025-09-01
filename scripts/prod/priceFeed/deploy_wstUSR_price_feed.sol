// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { wstUSRPriceFeed } from "../../../contracts/oracle/priceFeeds/wstUSRPriceFeed.sol";

contract yUSDPriceFeedTest is Script {
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address wstUSR_stUSR_PriceFeed = 0xA40a0dC23D3A821fF5Ea9E23080B74DAC031158d;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Interaction implementation
        wstUSRPriceFeed feed = new wstUSRPriceFeed(resilientOracle, wstUSR_stUSR_PriceFeed);
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}
