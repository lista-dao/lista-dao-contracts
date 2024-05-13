const hre = require("hardhat");
const {ethers} = hre;

const API3ProxyAddress = '';

async function main() {
  const API3Oracle = await ethers.getContractFactory("API3Oracle");
  const api3Oracle = await upgrades.deployProxy(API3Oracle, [API3ProxyAddress], { initializer: "initialize" });
  await api3Oracle.waitForDeployment();

  let api3OracleImplementation = await upgrades.erc1967.getImplementationAddress(api3Oracle.target);
  console.log("Deployed: API3Oracle    : " + api3Oracle.target);
  console.log("Imp                     : " + api3OracleImplementation);

  console.log('---------- verifying contract ----------')
  await hre.run("verify:verify", {
    address: api3Oracle.target,
    constructorArguments: [API3ProxyAddress]
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
