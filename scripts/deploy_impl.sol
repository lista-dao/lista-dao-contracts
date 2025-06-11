// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { Interaction } from "../contracts/Interaction.sol";

contract ImplDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy Interaction implementation
    Interaction impl = new Interaction();
    console.log("Interaction implementation: ", address(impl));

    vm.stopBroadcast();
  }
}
