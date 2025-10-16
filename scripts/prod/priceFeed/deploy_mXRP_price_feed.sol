// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import "../../../contracts/oracle/priceFeeds/mXRPPriceFeed.sol";

contract yUSDPriceFeedTest is Script {
    address resilientOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    address mXRP_XRP_PriceFeed = 0x3BdE0b7B59769Ec00c44C77090D88feB4516E731;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contract
        mXRPPriceFeed feed = new mXRPPriceFeed(resilientOracle, mXRP_XRP_PriceFeed);
        console.log("feed deployed to: ", address(feed));

        vm.stopBroadcast();
    }
}
