// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { CDPLiquidator } from "../contracts/CDPLiquidator.sol";

contract ImplDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy CDPLiquidator implementation
    CDPLiquidator impl = new CDPLiquidator();
    console.log("CDPLiquidator implementation: ", address(impl));

    vm.stopBroadcast();
  }
}
