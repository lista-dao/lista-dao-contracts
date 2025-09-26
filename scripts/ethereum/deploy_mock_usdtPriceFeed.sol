// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { MockPriceFeed } from "../../contracts/mock/MockPriceFeed.sol";

contract MockPriceFeedDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy MockPriceFeed
    MockPriceFeed mockPriceFeed = new MockPriceFeed();
    console.log("MockPriceFeed (WBTC) deployed at: ", address(mockPriceFeed));

    vm.stopBroadcast();
  }
}
