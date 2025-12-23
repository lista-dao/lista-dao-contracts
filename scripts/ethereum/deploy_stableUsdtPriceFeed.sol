// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { StableUsdtPriceFeed } from "../../contracts/oracle/priceFeeds/ethereum/StableUsdtPriceFeed.sol";

contract StableUsdtPriceFeedDeploy is Script {

  address resilientOracle = 0xA64FE284EB8279B9b63946DD51813b0116099301;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_BSC_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy StableUsdtPriceFeed
    StableUsdtPriceFeed stableUsdtPriceFeed = new StableUsdtPriceFeed(resilientOracle);
    console.log("StableUsdtPriceFeed deployed at: ", address(stableUsdtPriceFeed));

    vm.stopBroadcast();
  }
}
