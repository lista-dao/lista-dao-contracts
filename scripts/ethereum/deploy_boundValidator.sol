// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { BoundValidator } from "../../contracts/oracle/BoundValidator.sol";

contract BoundValidatorDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy BoundValidator implementation
    BoundValidator impl = new BoundValidator();
    console.log("BoundValidator implementation: ", address(impl));

    // Initialize data
    ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeWithSelector(BoundValidator.initialize.selector));
    console.log("BoundValidator proxy: ", address(proxy));

    vm.stopBroadcast();
  }
}
