const hre = require('hardhat')
const { ethers, upgrades } = hre;

let admin = '0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06';
async function main() {
    const MockResilientOracle = await hre.ethers.getContractFactory('MockResilientOracle');
    const mockResilientOracle = await upgrades.deployProxy(MockResilientOracle, [admin]);
    await mockResilientOracle.waitForDeployment();

    console.log('MockResilientOracle deployed to:', mockResilientOracle.target);
    await run("verify:verify", {
     address: mockResilientOracle.target,
     constructorArguments: [],
   });

 }

 main()
   .then(() => process.exit(0))
   .catch((error) => {
     console.error(error)
     process.exit(1)
   })
