// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { WstETHPriceFeed } from "../../contracts/oracle/priceFeeds/ethereum/WstETHPriceFeed.sol";

contract WstETHPriceFeedDeploy is Script {
  address resilientOracle = 0xA64FE284EB8279B9b63946DD51813b0116099301;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_BSC_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy WstETHPriceFeed
    WstETHPriceFeed wstETHPriceFeed = new WstETHPriceFeed(resilientOracle);
    console.log("WstETHPriceFeed deployed at: ", address(wstETHPriceFeed));

    vm.stopBroadcast();
  }
}
