// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { Interaction } from "../contracts/Interaction.sol";
import { HelioProviderV2 } from "../contracts/ceros/upgrades/HelioProviderV2.sol";
import { SlisBNBProvider } from "../contracts/ceros/provider/SlisBNBProvider.sol";

contract ImplDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy Interaction implementation
    Interaction impl = new Interaction();
    console.log("Interaction implementation: ", address(impl));

    // Deploy HelioProviderV2 implementation
    HelioProviderV2 providerImpl = new HelioProviderV2();
    console.log("HelioProviderV2 implementation: ", address(providerImpl));

    // Deploy SlisBNBProvider implementation
    SlisBNBProvider slisBNBImpl = new SlisBNBProvider();
    console.log("SlisBNBProvider implementation: ", address(slisBNBImpl));

    vm.stopBroadcast();
  }
}
