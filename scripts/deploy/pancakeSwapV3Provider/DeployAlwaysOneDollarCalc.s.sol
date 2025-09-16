// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import { AlwaysOneDollarCalc} from "../../../contracts/abaci.sol";

contract DeployAlwaysOneDollarCalc is Script {

  uint256 deployerPrivateKey;
  address deployer;

  function setUp() public {
    // load addresses
    deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    deployer = vm.addr(deployerPrivateKey);
  }

  function run() public {

    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    AlwaysOneDollarCalc alwaysOneDollarCalc = new AlwaysOneDollarCalc();

    console.log("AlwaysOneDollarCalc deployed at: ", address(alwaysOneDollarCalc));

    vm.stopBroadcast();
  }

}
