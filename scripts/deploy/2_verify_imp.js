const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");
const {ether} = require("@openzeppelin/test-helpers");

const network_file_name = `${network.name}_addresses.json`;

const {
    ceaBNBc,
    ceaBNBcImplementation,
    ceVault,
    ceVaultImplementation,
    hBNB,
    hBnbImplementation,
    cerosRouter,
    cerosRouterImplementation,
    abaci,
    abaciImplementation,
    oracle,
    oracleImplementation,
    vat,
    vatImplementation,
    spot,
    spotImplementation,
    hay,
    hayImplementation,
    hayJoin,
    hayJoinImplementation,
    bnbJoin,
    bnbJoinImplementation,
    jug,
    jugImplementation,
    vow,
    vowImplementation,
    dog,
    dogImplementation,
    clipCE,
    clipCEImplementation,
    rewards,
    rewardsImplementation,
    interaction,
    interactionImplementation,
    AuctionLib,
    helioProvider,
    helioProviderImplementation 
} = require('./' + network_file_name);

async function main() {

    // Verify all implementations
    await hre.run("verify:verify", {address: ceaBNBcImplementation});
    await hre.run("verify:verify", {address: ceVaultImplementation});
    await hre.run("verify:verify", {address: hBnbImplementation});
    await hre.run("verify:verify", {address: cerosRouterImplementation});
    await hre.run("verify:verify", {address: abaciImplementation});
    await hre.run("verify:verify", {address: oracleImplementation});
    await hre.run("verify:verify", {address: vatImplementation});
    await hre.run("verify:verify", {address: spotImplementation});
    await hre.run("verify:verify", {address: hayImplementation});
    await hre.run("verify:verify", {address: hayJoinImplementation});
    await hre.run("verify:verify", {address: bnbJoinImplementation});
    await hre.run("verify:verify", {address: jugImplementation});
    await hre.run("verify:verify", {address: vowImplementation});
    await hre.run("verify:verify", {address: dogImplementation});
    await hre.run("verify:verify", {address: clipCEImplementation});
    await hre.run("verify:verify", {address: rewardsImplementation});
    await hre.run("verify:verify", {address: AuctionLib});
    await hre.run("verify:verify", {address: interactionImplementation});
    await hre.run("verify:verify", {address: helioProviderImplementation});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
