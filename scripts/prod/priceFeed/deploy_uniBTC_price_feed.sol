// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { uniBTCPriceFeed } from "../../../contracts/oracle/priceFeeds/uniBTCPriceFeed.sol";

contract yUSDPriceFeedTest is Script {
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address uinBTC_BTC_PriceFeed = 0x921Fa3C67286385b22dE244e51E5925D98B03130;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Interaction implementation
        uniBTCPriceFeed feed = new uniBTCPriceFeed(resilientOracle, uinBTC_BTC_PriceFeed);
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}
