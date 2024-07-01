import hre from "hardhat";
import {ethers, upgrades} from "hardhat";

async function main() {

  // check network and contract name
  console.log("Network: ", hre.network.name);
  const contractName = /^bsc_testnet$/.test(hre.network.name) ? "SlisBnbOracleTestnet" : "SlisBnbOracle";
  const SlisBnbOracle = await ethers.getContractFactory(contractName);

  // check upgradability of the contract
  if (contractName === "SlisBnbOracle") {
    console.log('Validate if its upgradable...');
    const slisBnbOracleProxyAddress = '0x8ecf78fb59e5a4c26cb218d34db29c4696af89f6';
    const WBETHOracle = await ethers.getContractFactory('WBETHOracle');
    await upgrades.forceImport(slisBnbOracleProxyAddress, WBETHOracle, { kind: 'transparent' });
    const result = await upgrades.validateUpgrade(slisBnbOracleProxyAddress, SlisBnbOracle)
    console.log('Upgradability is validated successfully.');
  }

  // deploy implementation contract
  const slisBnbOracle = await SlisBnbOracle.deploy();
  await slisBnbOracle.deployed();
  console.log("Deployed: SlisBnbOracle: " + slisBnbOracle.address);

  // verify contract
  await hre.run("verify:verify",  {
      address: slisBnbOracle.address,
      constructorArguments: [],
  });
  console.log('Contract verified successfully.');

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

