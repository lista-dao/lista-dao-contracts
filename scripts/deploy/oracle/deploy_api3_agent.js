const hre = require("hardhat");
const {ethers} = hre;

const API3ProxyAddress = '';

async function main() {
  if (!API3ProxyAddress.length) {
    throw new Error('API3ProxyAddress is required');
  }
  const API3Oracle = await ethers.getContractFactory("API3Oracle");
  const api3Oracle = await API3Oracle.deploy(API3ProxyAddress);
  await api3Oracle.waitForDeployment();
  const api3OracleAddress = await api3Oracle.getAddress();
  console.log('contract deployed at: ', api3OracleAddress);
  // waiting for 5 blocks
  await new Promise((resolve) => setTimeout(resolve, 3000 * 5));
  console.log('---------- verifying contract ----------')
  await hre.run("verify:verify", {
    address: api3OracleAddress,
    constructorArguments: [API3ProxyAddress],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
