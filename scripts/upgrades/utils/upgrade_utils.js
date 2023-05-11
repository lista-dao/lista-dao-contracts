const {ethers, upgrades} = require("hardhat");

async function upgradeProxy(proxyAddress, impAddress) {
    const admin_slot = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

    const proxyAdminBytes = await ethers.provider.getStorageAt(proxyAddress, admin_slot);
    const PROXY_ADMIN_ABI = ["function upgrade(address proxy, address implementation) public"]
    
    const proxyAdminAddress = parseAddress(proxyAdminBytes);
    let proxyAdmin = await ethers.getContractAt(PROXY_ADMIN_ABI, proxyAdminAddress);
  
    if (proxyAdminAddress != ethers.constants.AddressZero) {
        await (await proxyAdmin.upgrade(proxyAddress, impAddress)).wait();
        console.log("Upgraded Successfully...")
    } else {
        console.log("Invalid proxyAdmin address");
    }
}

async function deployImplementatoin(contractName) {
    let contractFactory = await hre.ethers.getContractFactory(contractName);
    let contractImpl = await contractFactory.deploy();
    await contractImpl.deployed();
    console.log(`${contractName}Imp:  `,contractImpl.address)
    return contractImpl.address;
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
  return ethers.utils.getAddress(address);
}

module.exports = { upgradeProxy , deployImplementatoin , verifyImpContract}