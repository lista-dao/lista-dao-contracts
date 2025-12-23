// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ERC20UpgradeableMock } from "../../contracts/mock/ERC20UpgradeableMock.sol";

contract ERC20UpgradeableMockDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy ERC20UpgradeableMock
    ERC20UpgradeableMock erc20Mock = new ERC20UpgradeableMock();
    erc20Mock.initialize("Mock cbBTC Token", "MOCK-cbBTC");
    console.log("ERC20UpgradeableMock deployed at: ", address(erc20Mock));

    vm.stopBroadcast();
  }
}
