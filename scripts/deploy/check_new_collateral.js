const Web3 = require('web3');
const assert = require('assert');
const {getProxyAdminAddress} = require('../upgrades/utils/upgrade_utils')
const allConfig = require('./check_new_collateral.json');
const {ethers} = require("hardhat");

async function main() {
    let rpc_url = 'https://bsc-dataseed.binance.org/';

    if (hre.network.name === 'bsc_testnet') {
        rpc_url = 'https://data-seed-prebsc-1-s1.binance.org:8545/';
    }

    const web3 = new Web3(rpc_url);


    console.log("check gemJoin")
    let gemJoinContract = await ethers.getContractAt(allConfig["gemJoinAbi"], allConfig["gemJoin"]);

    const gemJoinGem = await gemJoinContract.gem();

    assert.strictEqual(gemJoinGem.toLowerCase(), allConfig["tokenAddress"].toLowerCase(), '[gemJoin] token address is wrong!');
    console.log("[gemJoin] check gem address ok")

    const gemJoinIlk = await gemJoinContract.ilk();

    assert.strictEqual(gemJoinIlk, allConfig["ilk"], '[gemJoin] ilk is wrong!');
    console.log("[gemJoin] check ilk ok")


    const gemJoinVat = await gemJoinContract.vat();

    assert.strictEqual(gemJoinVat.toLowerCase(), allConfig["VAT"].toLowerCase(), '[gemJoin] vat is wrong!');
    console.log("[gemJoin] check vat ok")

    const gemJoinProxyAdminAddress = await getProxyAdminAddress(allConfig["gemJoin"]);
    console.log('[gemJoin] proxy admin: ', gemJoinProxyAdminAddress);

    let gemJoinProxyAdmin = await ethers.getContractAt(allConfig["proxyAdminAbi"], gemJoinProxyAdminAddress);

    const gemJoinProxyAdminOwner = await gemJoinProxyAdmin.owner();
    console.log("[gemJoin] proxy admin owner: ", gemJoinProxyAdminOwner);


    console.log("check clipper")

    let clipperContract = await ethers.getContractAt(allConfig["clipperAbi"], allConfig["clipper"]);

    const clipperVat = await clipperContract.vat();

    assert.strictEqual(clipperVat.toLowerCase(), allConfig["VAT"].toLowerCase(), '[clipper] vat is wrong!');
    console.log("[clipper] check vat ok")


    const clipperSpot = await clipperContract.spotter();

    assert.strictEqual(clipperSpot.toLowerCase(), allConfig["SPOT"].toLowerCase(), '[clipper] spot is wrong!');
    console.log("[clipper] check spot ok")

    const clipperDog = await clipperContract.dog();

    assert.strictEqual(clipperDog.toLowerCase(), allConfig["DOG"].toLowerCase(), '[clipper] dog is wrong!');
    console.log("[clipper] check dog ok")

    const clipperIlk = await clipperContract.ilk();

    assert.strictEqual(clipperIlk, allConfig["ilk"], '[clipper] ilk is wrong!');
    console.log("[clipper] check ilk ok")


    const clipperVow = await clipperContract.vow();

    assert.strictEqual(clipperVow.toLowerCase(), allConfig["VOW"].toLowerCase(), '[clipper] vow is wrong!');
    console.log("[clipper] check vow ok")

    const clipperCalc = await clipperContract.calc();

    assert.strictEqual(clipperCalc.toLowerCase(), allConfig["ABACI"].toLowerCase(), '[clipper] calc is wrong!');
    console.log("[clipper] check calc ok")

    const clipperBuf = await clipperContract.buf();
    console.log("[clipper] buf: ", clipperBuf);

    const clipperTail = await clipperContract.tail();
    console.log("[clipper] tail: ", clipperTail);

    const clipperCusp = await clipperContract.cusp();
    console.log("[clipper] cusp: ", clipperCusp);

    const clipperChip = await clipperContract.chip();
    console.log("[clipper] cusp: ", clipperChip);

    const clipperTip = await clipperContract.tip();
    console.log("[clipper] tip: ", clipperTip);

    const clipperStopped = await clipperContract.stopped();
    console.log("[clipper] stopped: ", clipperStopped);


    const clipperProxyAdminAddress = await getProxyAdminAddress(allConfig["clipper"]);
    console.log('[clipper] proxy admin: ', clipperProxyAdminAddress);

    let clipperProxyAdmin = await ethers.getContractAt(allConfig["proxyAdminAbi"], gemJoinProxyAdminAddress);

    const clipperProxyAdminOwner = await clipperProxyAdmin.owner();
    console.log("[clipper] proxy admin owner: ", clipperProxyAdminOwner);


    console.log("check oracle")

    const oracleProxyAdminAddress = await getProxyAdminAddress(allConfig["oracle"]);
    console.log('[oracle] proxy admin: ', oracleProxyAdminAddress);

    let oracleProxyAdmin = await ethers.getContractAt(allConfig["proxyAdminAbi"], oracleProxyAdminAddress);

    const oracleProxyAdminOwner = await oracleProxyAdmin.owner();
    console.log("[oracle] proxy admin owner: ", oracleProxyAdminOwner);


    console.log("check rely")
    let gemJoinInteractionRely = await gemJoinContract['wards(address)'](allConfig["INTERACTION"]);
    assert.equal(gemJoinInteractionRely, 1, '[gemJoin] interaction not rely');
    console.log("[rely] gemJoin to interaction ok");


    let clipperInteractionRely = await clipperContract['wards(address)'](allConfig["INTERACTION"]);
    assert.equal(clipperInteractionRely, 1, '[clipper] interaction not rely');

    console.log("[rely] clipper to interaction ok");

    let clipperDogRely = await clipperContract['wards(address)'](allConfig["DOG"]);
    assert.equal(clipperDogRely, 1, '[clipper] dog not rely');
    console.log("[rely] clipper to dog ok");

    console.log("check contract deploy finished")


    console.log("check runbook execute start..");

    let spotContract = await ethers.getContractAt(allConfig["spotAbi"], allConfig["SPOT"]);
    let spotIlk = await spotContract['ilks(bytes32)'](allConfig["ilk"]);

    assert.strictEqual(spotIlk[0].toLowerCase(), allConfig["oracle"].toLowerCase(), '[spot] pip is wrong!');
    console.log("[spot] check pip ok")
    console.log("[spot] mat: ", spotIlk[1]);



    let vatContract = await ethers.getContractAt(allConfig["vatAbi"], allConfig["VAT"]);

    let vatGemJoinRely = await vatContract['wards(address)'](allConfig["gemJoin"]);
    let vatClipperRely = await vatContract['wards(address)'](allConfig["clipper"]);
    assert.equal(vatGemJoinRely, 1, '[vat] gemJoin not rely');
    assert.equal(vatClipperRely, 1, '[vat] clipper not rely');
    console.log("[rely] vat to gemJoin ok");
    console.log("[rely] vat to clipper ok");

    let vatIlk = await vatContract['ilks(bytes32)'](allConfig["ilk"]);

    console.log("[vat] line: ", vatIlk[3]);
    console.log("[vat] dust: ", vatIlk[4]);
    if (vatIlk[3] <= 0) {
        console.log("WARNING: [vat] ilk spot is 0, need poke");
    }


    let dogContract = await ethers.getContractAt(allConfig["dogAbi"], allConfig["DOG"]);

    let dogClipperRely = await dogContract['wards(address)'](allConfig["clipper"]);
    assert.equal(dogClipperRely, 1, '[dog] clipper not rely');
    console.log("[rely] dog to clipper ok");

    let dogIlk = await dogContract['ilks(bytes32)'](allConfig["ilk"]);

    console.log("[dog] clip: ", dogIlk[0]);
    console.log("[dog] chop: ", dogIlk[1]);
    console.log("[dog] hole: ", dogIlk[2]);



    let jugContract = await ethers.getContractAt(allConfig["jugAbi"], allConfig["JUG"]);


    let jugIlk = await jugContract['ilks(bytes32)'](allConfig["ilk"]);

    console.log("[jug] duty: ", jugIlk[0]);


    console.log("check finished")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
