const assert = require('assert');
const {getProxyAdminAddress} = require('../upgrades/utils/upgrade_utils')
//const allConfig = require('./check_new_collateral.json');
const allConfig = require('./check_new_collateral_prod.json');
const {ethers} = require("hardhat");
const hre = require("hardhat");
const contractAddresses = require("./contract_address.json");

async function main() {
    const {
        VAT,
        DOG,
        SPOT,
        INTERACTION,
        VOW,
        ABACI,
        JUG
    } = (hre.network.name === 'bsc_testnet') ? contractAddresses["testnet"] : contractAddresses["mainnet"];

    console.log("check gemJoin")
    const PROXY_ADMIN_ABI = ["function transferOwnership(address newOwner) public","function owner() public view returns (address)"]
    this.GemJoin = await hre.ethers.getContractFactory('GemJoin')
    const gemJoinContract = this.GemJoin.attach(allConfig["gemJoin"])

    const gemJoinGem = await gemJoinContract.gem();

    assert.strictEqual(gemJoinGem.toLowerCase(), allConfig["tokenAddress"].toLowerCase(), '[gemJoin] token address is wrong!');
    console.log("[gemJoin] check gem address ok")

    const gemJoinIlk = await gemJoinContract.ilk();

    assert.strictEqual(gemJoinIlk, allConfig["ilk"], '[gemJoin] ilk is wrong!');
    console.log("[gemJoin] check ilk ok")


    const gemJoinVat = await gemJoinContract.vat();

    assert.strictEqual(gemJoinVat.toLowerCase(), VAT.toLowerCase(), '[gemJoin] vat is wrong!');
    console.log("[gemJoin] check vat ok")

    const gemJoinProxyAdminAddress = await getProxyAdminAddress(allConfig["gemJoin"]);

    assert.strictEqual(gemJoinProxyAdminAddress.toLowerCase(), allConfig["gemJoinProxyAdmin"].toLowerCase(), '[gemJoin] proxy admin address is wrong!');
    console.log('[gemJoin] proxy admin ok');


    let gemJoinProxyAdmin = await ethers.getContractAt(PROXY_ADMIN_ABI, gemJoinProxyAdminAddress);

    const gemJoinProxyAdminOwner = await gemJoinProxyAdmin.owner();

    assert.strictEqual(gemJoinProxyAdminOwner.toLowerCase(), allConfig["gemJoinProxyAdminOwner"].toLowerCase(), '[gemJoin] proxy admin owner is wrong!');
    console.log('[gemJoin] proxy admin owner ok');

    console.log("check clipper")

    this.Clipper = await hre.ethers.getContractFactory('Clipper')
    const clipperContract = this.Clipper.attach(allConfig["clipper"])

    const clipperVat = await clipperContract.vat();

    assert.strictEqual(clipperVat.toLowerCase(), VAT.toLowerCase(), '[clipper] vat is wrong!');
    console.log("[clipper] check vat ok")


    const clipperSpot = await clipperContract.spotter();

    assert.strictEqual(clipperSpot.toLowerCase(), SPOT.toLowerCase(), '[clipper] spot is wrong!');
    console.log("[clipper] check spot ok")

    const clipperDog = await clipperContract.dog();

    assert.strictEqual(clipperDog.toLowerCase(), DOG.toLowerCase(), '[clipper] dog is wrong!');
    console.log("[clipper] check dog ok")

    const clipperIlk = await clipperContract.ilk();

    assert.strictEqual(clipperIlk, allConfig["ilk"], '[clipper] ilk is wrong!');
    console.log("[clipper] check ilk ok")


    const clipperVow = await clipperContract.vow();

    assert.strictEqual(clipperVow.toLowerCase(), VOW.toLowerCase(), '[clipper] vow is wrong!');
    console.log("[clipper] check vow ok")

    const clipperCalc = await clipperContract.calc();

    assert.strictEqual(clipperCalc.toLowerCase(), ABACI.toLowerCase(), '[clipper] calc is wrong!');
    console.log("[clipper] check calc ok")

    const clipperBuf = await clipperContract.buf();

    assert.equal(clipperBuf, allConfig["buf"], '[clipper] buf is wrong!');
    console.log("[clipper] buf ok");

    const clipperTail = await clipperContract.tail();
    assert.equal(clipperTail, allConfig["tail"], '[clipper] tail is wrong!');
    console.log("[clipper] tail ok");



    const clipperCusp = await clipperContract.cusp();
    assert.equal(clipperCusp, allConfig["cusp"], '[clipper] cusp is wrong!');
    console.log("[clipper] cusp ok");


    const clipperChip = await clipperContract.chip();
    assert.equal(clipperChip, allConfig["chip"], '[clipper] chip is wrong!');
    console.log("[clipper] chip ok");

    const clipperTip = await clipperContract.tip();
    assert.equal(clipperTip, allConfig["tip"], '[clipper] tip is wrong!');
    console.log("[clipper] tip ok");




    const clipperStopped = await clipperContract.stopped();
    assert.equal(clipperStopped, allConfig["stopped"], '[clipper] stopped is wrong!');
    console.log("[clipper] stopped ok");



    const clipperProxyAdminAddress = await getProxyAdminAddress(allConfig["clipper"]);
    assert.strictEqual(clipperProxyAdminAddress.toLowerCase(), allConfig["clipperProxyAdmin"].toLowerCase(), '[clipper] proxy admin address is wrong!');
    console.log('[clipper] proxy admin ok');


    let clipperProxyAdmin = await ethers.getContractAt(PROXY_ADMIN_ABI, gemJoinProxyAdminAddress);

    const clipperProxyAdminOwner = await clipperProxyAdmin.owner();
    assert.strictEqual(clipperProxyAdminOwner.toLowerCase(), allConfig["clipperProxyAdminOwner"].toLowerCase(), '[clipper] proxy admin owner is wrong!');
    console.log('[clipper] proxy admin owner ok');


    console.log("check oracle")

    const oracleProxyAdminAddress = await getProxyAdminAddress(allConfig["oracle"]);
    assert.strictEqual(oracleProxyAdminAddress.toLowerCase(), allConfig["oracleProxyAdmin"].toLowerCase(), '[oracle] proxy admin address is wrong!');
    console.log('[oracle] proxy admin ok');




    let oracleProxyAdmin = await ethers.getContractAt(PROXY_ADMIN_ABI, oracleProxyAdminAddress);

    const oracleProxyAdminOwner = await oracleProxyAdmin.owner();

    assert.strictEqual(oracleProxyAdminOwner.toLowerCase(), allConfig["oracleProxyAdminOwner"].toLowerCase(), '[oracle] proxy admin owner is wrong!');
    console.log('[oracle] proxy admin owner ok');


    console.log("check rely")
    let gemJoinInteractionRely = await gemJoinContract['wards(address)'](INTERACTION);
    assert.equal(gemJoinInteractionRely, 1, '[gemJoin] interaction not rely');
    console.log("[rely] gemJoin to interaction ok");


    let clipperInteractionRely = await clipperContract['wards(address)'](INTERACTION);
    assert.equal(clipperInteractionRely, 1, '[clipper] interaction not rely');

    console.log("[rely] clipper to interaction ok");

    let clipperDogRely = await clipperContract['wards(address)'](DOG);
    assert.equal(clipperDogRely, 1, '[clipper] dog not rely');
    console.log("[rely] clipper to dog ok");

    console.log("check contract deploy finished")


    console.log("check runbook execute start..");

    this.Spotter = await hre.ethers.getContractFactory('Spotter')
    const spotContract = this.Spotter.attach(SPOT)

    let spotIlk = await spotContract['ilks(bytes32)'](allConfig["ilk"]);

    assert.strictEqual(spotIlk[0].toLowerCase(), allConfig["oracle"].toLowerCase(), '[spot] pip is wrong!');
    console.log("[spot] check pip ok")

    assert.equal(spotIlk[1], allConfig["mat"], '[spot] ilk mat is wrong!');
    console.log("[spot] mat ok");

    this.Vat = await hre.ethers.getContractFactory('Vat')
    const vatContract = this.Vat.attach(VAT)

    let vatGemJoinRely = await vatContract['wards(address)'](allConfig["gemJoin"]);
    let vatClipperRely = await vatContract['wards(address)'](allConfig["clipper"]);
    assert.equal(vatGemJoinRely, 1, '[vat] gemJoin not rely');
    assert.equal(vatClipperRely, 1, '[vat] clipper not rely');
    console.log("[rely] vat to gemJoin ok");
    console.log("[rely] vat to clipper ok");

    let vatIlk = await vatContract['ilks(bytes32)'](allConfig["ilk"]);



    assert.equal(vatIlk[3], allConfig["line"], '[vat] ilk line is wrong!');
    console.log("[vat] line ok");
    assert.equal(vatIlk[4], allConfig["dust"], '[vat] ilk dust is wrong!');
    console.log("[vat] dust ok");



    if (vatIlk[3] <= 0) {
        console.log("WARNING: [vat] ilk spot is 0, need poke");
    }


    this.Dog = await hre.ethers.getContractFactory('Dog')
    const dogContract = this.Dog.attach(DOG)

    let dogClipperRely = await dogContract['wards(address)'](allConfig["clipper"]);
    assert.equal(dogClipperRely, 1, '[dog] clipper not rely');
    console.log("[rely] dog to clipper ok");

    let dogIlk = await dogContract['ilks(bytes32)'](allConfig["ilk"]);


    assert.strictEqual(dogIlk[0].toLowerCase(), allConfig["clipper"].toLowerCase(), '[dog] ilk clip is wrong!');
    console.log("[dog] clip ok");
    assert.equal(dogIlk[1], allConfig["chop"], '[dog] ilk chop is wrong!');
    console.log("[dog] chop ok");
    assert.equal(dogIlk[2], allConfig["hole"], '[dog] ilk hole is wrong!');
    console.log("[dog] hole ok");


    this.Jug = await hre.ethers.getContractFactory('Jug')
    const jugContract = this.Jug.attach(JUG)

    let jugIlk = await jugContract['ilks(bytes32)'](allConfig["ilk"]);

    // console.log("[jug] duty: ", jugIlk[0]);
    assert.equal(jugIlk[0], allConfig["duty"], '[jug] ilk duty is wrong!');
    console.log("[jug] duty ok");
    console.log("check finished")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
