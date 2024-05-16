const {ethers, upgrades} = require("hardhat");

async function upgradeProxy(proxyAddress, impAddress) {
    const PROXY_ADMIN_ABI = ["function upgrade(address proxy, address implementation) public"]
    const proxyAdminAddress = await getProxyAdminAddress(proxyAddress);
    let proxyAdmin = await ethers.getContractAt(PROXY_ADMIN_ABI, proxyAdminAddress);

    if (proxyAdminAddress !== ethers.ZeroAddress) {
        await (await proxyAdmin.upgrade(proxyAddress, impAddress)).wait();
        console.log("Upgraded Successfully...")
    } else {
        console.log("Invalid proxyAdmin address");
    }
}

async function deployImplementation(contractName, args) {
    let contractFactory = await ethers.getContractFactory(contractName, args);
    let contractImpl = await contractFactory.deploy();
    await contractImpl.deploymentTransaction().wait(6);
    const address = await contractImpl.getAddress();
    console.log(`${contractName}Imp:  `, address)
    return address;
}

async function verifyImpContract(ImpAddress) {
    await hre.run("verify:verify", {address: ImpAddress});
}

function parseAddress(addressString){
  const buf = Buffer.from(addressString.replace(/^0x/, ''), 'hex');
  if (!buf.slice(0, 12).equals(Buffer.alloc(12, 0))) {
    return undefined;
  }
  const address = '0x' + buf.toString('hex', 12, 32); // grab the last 20 bytes
  return ethers.getAddress(address);
}

/**
 * get proxy admin address from proxy address
 * @param proxyAddress
 * @return {Promise<*>}
 */
async function getProxyAdminAddress(proxyAddress) {
  const admin_slot = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";
  const proxyAdminBytes = await ethers.provider.getStorage(proxyAddress, admin_slot);
  return parseAddress(proxyAdminBytes);
}

/**
 *
 * @param proxyAddress
 * @param newOwner
 * @return {Promise<void>}
 */
async function transferProxyAdminOwner(proxyAddress, newOwner) {
  const PROXY_ADMIN_ABI = ["function transferOwnership(address newOwner) public","function owner() public view returns (address)"]

  const proxyAdminAddress = await getProxyAdminAddress(proxyAddress);
  let proxyAdmin = await ethers.getContractAt(PROXY_ADMIN_ABI, proxyAdminAddress);

  if (proxyAdminAddress !== ethers.ZeroAddress) {
    // check if the current owner is the deployer
    const owner = await proxyAdmin.owner();
    if (owner !== newOwner) {
      console.log(`ProxyAdmin: ${proxyAdminAddress} Owner: ${owner} NewOwner: ${newOwner}`)
      await (await proxyAdmin.transferOwnership(newOwner)).wait(3);
      console.log(`ProxyAdmin Ownership Transferred Successfully...`)
    } else {
      console.log("ProxyAdmin already owned by newOwner");
    }
  } else {
    console.log("Invalid proxyAdmin address");
  }
}

module.exports = { upgradeProxy , deployImplementation , verifyImpContract, getProxyAdminAddress, transferProxyAdminOwner }
