const hre = require("hardhat");
const {ethers} = hre;

const API3ProxyAddress = '';

async function main() {
  const API3Oracle = await ethers.getContractFactory("API3Oracle");
  const api3Oracle = await API3Oracle.deploy();
  await api3Oracle.waitForDeployment();
  const api3OracleAddress = await api3Oracle.getAddress();
  console.log('contract deployed at: ', api3OracleAddress);
  console.log('---------- verifying contract ----------')
  await hre.run("verify:verify", {
    address: api3OracleAddress
  });
  // set proxy address
  const tx = await api3Oracle.initialize(API3ProxyAddress);
  await tx.wait(3);
  console.log('proxy is set');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
