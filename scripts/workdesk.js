const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");
const {ether} = require("@openzeppelin/test-helpers");


async function main() {

  let [deployer] = await ethers.getSigners();

  // Contracts Fetching
  this.ElipsisMediator = await hre.ethers.getContractFactory("ElipsisMediator");
  this.Jar = await hre.ethers.getContractFactory("Jar");

  // Contracts Deployment
  let jar = await Jar.deploy();
  console.log("Deployed: Jug        : " + jar.address);

  let em = await upgrades.deployProxy(this.ElipsisMediator, ["0x305A3c22170065003a9BC9ea17fF95999102E785"], {initializer: "initialize"});
  await em.deployed();
  let emImp = await upgrades.erc1967.getImplementationAddress(em.address);
  console.log("Deployed: Mediator   : " + em.address);
  console.log("Imp                  : " + emImp);

  // Contracts Initialization
  await em.relyOperator("0x87e70D500E4ef21b28F0949E1650a3873e74ec9c");

  // Upgrades
  const admin_slot = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";
  const jarProxy = "0x0a1Fd12F73432928C190CAF0810b3B767A59717e";

  const proxyAddress = await ethers.provider.getStorageAt(jarProxy, admin_slot);
  const PROXY_ADMIN_ABI = ["function upgrade(address proxy, address implementation) public"]

  const proxyAdminAddress = parseAddress(proxyAddress);
  let proxyAdmin = await ethers.getContractAt(PROXY_ADMIN_ABI, proxyAdminAddress);

  if (proxyAdminAddress != ethers.constants.AddressZero) {
    await (await proxyAdmin.upgrade(jarProxy, jar.address)).wait();
    console.log("Upgraded Successfully...")
  } else {
    console.log("Invalid proxyAdmin address");
  }

  // Update Jar vars
  let jarContract = await ethers.getContractAt("Jar", jarProxy);
  await jarContract.addOperator("0x87e70D500E4ef21b28F0949E1650a3873e74ec9c");
  await jarContract.removeOperator("0x57F9672bA603251C9C03B36cabdBBcA7Ca8Cfcf4");
  await jarContract.setExitDelay(0);
  await jarContract.setSpread(604800);

  // Verify
  await hre.run("verify:verify", {address: jar.address});
  await hre.run("verify:verify", {address: emImp.address});
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