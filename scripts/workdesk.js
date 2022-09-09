const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");
const {ether} = require("@openzeppelin/test-helpers");

async function main() {

  let [deployer] = await ethers.getSigners();
  const admin_slot = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";
  
  // Contracts Fetching
  let em = await hre.ethers.getContractAt("ElipsisMediator", "0xd5193c2b05F44c35BcAB405f8d702E866f8e2cd1");
  let incentiveVoting = "0xdE1F4c0DD8C22b421851Fb51862F265D7564bEf7";
  let farming = "0xf0fA2307392e3b0bD742437C6f80C6C56Fd8A37f";
  let pancakeProxy = "0xbf0E241DE91B9230b03d1C968083226905773aA0";
  let pancakeStrategy = "0x5A2CcC1f8BB9a3048885E5F38bB48463E6314B7C";
 
  let proxyAddress = await ethers.provider.getStorageAt(farming, admin_slot);

  const TRANSFER_OWNERSHIP_ABI = ["function transferOwnership(address newOwner) public"]
  const VOTE_ABI = ["function vote(uint256[] _pids, uint256[] _votes) external"]

  const proxyAdminAddress = parseAddress(proxyAddress);
  let proxyAdmin = await ethers.getContractAt(TRANSFER_OWNERSHIP_ABI, proxyAdminAddress);

  let ivvote = await hre.ethers.getContractAt(VOTE_ABI, incentiveVoting);

  let iv = await hre.ethers.getContractAt(TRANSFER_OWNERSHIP_ABI, incentiveVoting);
  let fa = await hre.ethers.getContractAt(TRANSFER_OWNERSHIP_ABI, farming);
  let pp = await hre.ethers.getContractAt(TRANSFER_OWNERSHIP_ABI, pancakeProxy);
  let ps = await hre.ethers.getContractAt(TRANSFER_OWNERSHIP_ABI, pancakeStrategy);

  await em.rely("0x8d388136d578dCD791D081c6042284CED6d9B0c6");   console.log("Rely");
  await em.relyOperator("0x8d388136d578dCD791D081c6042284CED6d9B0c6"); console.log("RelyOperator");
  await em.denyOperator("0x87e70D500E4ef21b28F0949E1650a3873e74ec9c"); console.log("DenyOperator");
  await em.deny(deployer.address); console.log("Deny");

  await ivvote.vote([0], [1]); console.log("Vote");
  await iv.transferOwnership("0x8d388136d578dCD791D081c6042284CED6d9B0c6"); console.log("TransferOwnership");
  await fa.transferOwnership("0x8d388136d578dCD791D081c6042284CED6d9B0c6"); console.log("TransferOwnership");
  await pp.transferOwnership("0x8d388136d578dCD791D081c6042284CED6d9B0c6"); console.log("TransferOwnership");
  await ps.transferOwnership("0x8d388136d578dCD791D081c6042284CED6d9B0c6"); console.log("TransferOwnership");

  await proxyAdmin.transferOwnership("0x08aE09467ff962aF105c23775B9Bc8EAa175D27F"); console.log("TransferOwnership");
}

function parseAddress(addressString){
  const buf = Buffer.from(addressString.replace(/^0x/, ''), 'hex');
  if (!buf.slice(0, 12).equals(Buffer.alloc(12, 0))) {
    return undefined;
  }
  const address = '0x' + buf.toString('hex', 12, 32); // grab the last 20 bytes
  return ethers.utils.getAddress(address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });