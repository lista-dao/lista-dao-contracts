const hre = require('hardhat');
const {ethers} = hre;

const contractName = 'clisBNB'

async function main() {
  console.log('Running deploy script...')
  const contractFactory = await ethers.getContractFactory(contractName);
  const contractImpl = await contractFactory.deploy();
  await contractImpl.deploymentTransaction().wait(3);
  console.log("Contract deployed.");
  const address = await contractImpl.getAddress();
  console.log(`${contractName} Implementation: `, address)
  // verify
  await hre.run("verify:verify", { address });
  console.log("---- Done ----");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
