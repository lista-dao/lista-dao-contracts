const hre = require('hardhat')
const { ethers, upgrades } = hre;

async function main() {
  console.log('Upgrading ETHOracle...');
  const ETHOracleLegacy = await ethers.getContractFactory('EthOracle')
  const ETHOracle = await ethers.getContractFactory('EthOracleMock')
  // validate can upgrade or not
  await upgrades.validateUpgrade(ETHOracleLegacy, ETHOracle);
  console.log('can upgrade.');

  // upgrade EthOracle
  await upgrades.forceImport('0x0b3D79f2181545e0338b4644c2410ea59f39C7F1', ETHOracleLegacy);
  const upgrade = await upgrades.upgradeProxy('0x0b3D79f2181545e0338b4644c2410ea59f39C7F1', ETHOracle);
  const implAddress = await upgrades.erc1967.getImplementationAddress(upgrade.address);

  await hre.run("verify:verify", {
    address: implAddress,
  });

  console.log('Finished');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
