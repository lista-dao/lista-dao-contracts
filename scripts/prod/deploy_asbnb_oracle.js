const {upgrades, run} = require('hardhat')
const hre = require('hardhat')

let ASBNB_MINTER = "0x2F31ab8950c50080E77999fa456372f276952fD8"
let ADMIN = "0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253"

if (hre.network.name !== 'bsc') {
  ASBNB_MINTER = "0xb42096BCfdb216C89A314A011e3AFbb7Bab03d35"
  ADMIN = "0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06"
}

async function main() {
  const signers = await hre.ethers.getSigners();
  const deployer = signers[0].address;
  const admin = deployer;

  const AsBnbOracle = await hre.ethers.getContractFactory('AsBnbOracle');
  const asBnbOracle = await upgrades.deployProxy(AsBnbOracle, [ADMIN]);
  await asBnbOracle.waitForDeployment(3);

  const proxyAddress = await asBnbOracle.getAddress();

  console.log('AsBnbOracle deployed to:', proxyAddress);
  try {
    await run("verify:verify", {
      address: proxyAddress,
    });
  } catch (error) {
    console.error('error verifying contract:', error);
  }

  console.log('AsBnbOracle deploy and setup done');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
