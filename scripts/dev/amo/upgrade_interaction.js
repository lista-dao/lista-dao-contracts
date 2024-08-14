const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let PROXY = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279';
let AuctionProxyAddress = '0xC6e80f443c56F93b2ec1b6bc8942e161dDf22716';
async function main() {
    const InteractionImpl = await hre.ethers.getContractFactory("Interaction", {
        libraries: {AuctionProxy: AuctionProxyAddress,},
    });

    await upgrades.validateUpgrade(PROXY, InteractionImpl, {unsafeAllow: ["external-library-linking"]});
    console.log('Validate Upgrade Done');

    const interaction = await upgrades.upgradeProxy(PROXY, InteractionImpl, {unsafeAllow: ["external-library-linking"]});
    console.log('Interaction upgraded at:', interaction.target);
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
