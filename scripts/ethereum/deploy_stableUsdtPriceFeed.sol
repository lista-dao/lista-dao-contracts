// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { StableUsdtPriceFeed } from "../../contracts/oracle/priceFeeds/ethereum/StableUsdtPriceFeed.sol";

contract StableUsdtPriceFeedDeploy is Script {

  address resilientOracleAddr_mock = 0x05F8B0D79CA88A6B91419068b2Cd7eDA5a1A9b8d;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy StableUsdtPriceFeed
    StableUsdtPriceFeed stableUsdtPriceFeed = new StableUsdtPriceFeed(resilientOracleAddr_mock);
    console.log("StableUsdtPriceFeed deployed at: ", address(stableUsdtPriceFeed));

    vm.stopBroadcast();
  }
}
