// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { WBETHPriceFeed } from "../../contracts/oracle/priceFeeds/ethereum/WBETHPriceFeed.sol";

contract WBETHPriceFeedDeploy is Script {
  address resilientOracleAddr;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy WBETHPriceFeed
    WBETHPriceFeed wBETHPriceFeed = new WBETHPriceFeed(resilientOracleAddr);
    console.log("WBETHPriceFeed deployed at: ", address(wBETHPriceFeed));

    vm.stopBroadcast();
  }
}
