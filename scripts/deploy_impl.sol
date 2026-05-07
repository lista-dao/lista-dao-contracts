// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { SlisBNBProvider } from "../contracts/ceros/provider/SlisBNBProvider.sol";

contract ImplDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy SlisBNBProvider implementation
    SlisBNBProvider slisBNBImpl = new SlisBNBProvider();
    console.log("SlisBNBProvider implementation: ", address(slisBNBImpl));

    vm.stopBroadcast();
  }
}
