// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { SlisBNBProvider } from "../../../contracts/ceros/provider/SlisBNBProvider.sol";
import { mBTCProvider } from "../../../contracts/ceros/provider/mBTCProvider.sol";
import { PumpBTCProvider } from "../../../contracts/ceros/provider/PumpBTCProvider.sol";
import { HelioETHProvider } from "../../../contracts/ceros/ETH/HelioETHProvider.sol";
import { HelioProviderV2 } from "../../../contracts/ceros/upgrades/HelioProviderV2.sol";

contract DeployProviderImpls is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy SlisBNBProvider implementation
    SlisBNBProvider slisBNBProviderImpl = new SlisBNBProvider();
    console.log("SlisBNBProvider implementation: ", address(slisBNBProviderImpl));
    // Deploy mBTCProvider implementation
    mBTCProvider mBTCProviderImpl = new mBTCProvider();
    console.log("mBTCProvider implementation: ", address(mBTCProviderImpl));
    // Deploy PumpBTCProvider implementation
    PumpBTCProvider pumpBTCProviderImpl = new PumpBTCProvider();
    console.log("PumpBTCProvider implementation: ", address(pumpBTCProviderImpl));
    // Deploy HelioETHProvider implementation
    HelioETHProvider helioETHProviderImpl = new HelioETHProvider();
    console.log("HelioETHProvider implementation: ", address(helioETHProviderImpl));
    // Deploy HelioProviderV2 implementation
    HelioProviderV2 helioProviderV2Impl = new HelioProviderV2();
    console.log("HelioProviderV2 implementation: ", address(helioProviderV2Impl));

    vm.stopBroadcast();
  }
}
