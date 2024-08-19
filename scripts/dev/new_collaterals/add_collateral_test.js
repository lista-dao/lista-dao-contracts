const fs = require("fs");
const path = require("path");
const {ethers, upgrades} = require("hardhat");
const hre = require('hardhat')

// Global Variables
let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

    [deployer] = await ethers.getSigners();
    // token address
    let TOKEN = "0x4BB2f2AA54c6663BFFD37b54eCd88eD81bC8B3ec";  //btcb
    //let TOKEN = "0x4BB2f2AA54c6663BFFD37b54eCd88eD81bC8B3ec";  //btcb
    //let TOKEN = "0x4BB2f2AA54c6663BFFD37b54eCd88eD81bC8B3ec";  //btcb
    //let TOKEN = "0x4BB2f2AA54c6663BFFD37b54eCd88eD81bC8B3ec";  //btcb

    let INTERACTION = "0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4";
    let AUCTION_PROXY = '0x272d6589cecc19165cfcd0466f73a648cb1ea700';
    let LISUSD = '0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5';

    if (hre.network.name === "bsc_testnet") {
        LISUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';
        INTERACTION = "0x70C4880A3f022b32810a4E9B9F26218Ec026f279";
        AUCTION_PROXY = '0xa8d7806c77a5E844E05A8C07f18E3e2a9a2B39bb';
        if (!AUCTION_PROXY) {
            // deploy AuctionProxy
            const AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");
            const auctionProxy = await AuctionProxy.deploy();
            await auctionProxy.waitForDeployment();
            AUCTION_PROXY = await auctionProxy.getAddress();
            console.log("AuctionProxy deployed to:", AUCTION_PROXY);
        }
    }

    this.Interaction = await hre.ethers.getContractFactory("Interaction", {
        unsafeAllow: ['external-library-linking'],
        libraries: {
            AuctionProxy: AUCTION_PROXY
        },
    });

    const interaction = this.Interaction.attach(INTERACTION);
    // approve lisusd
    console.log("Approving LisUSD...");
    this.LisUsd = await ethers.getContractFactory("LisUSD");
    const lisusd = this.LisUsd.attach(LISUSD);
    await lisusd.approve(INTERACTION, ethers.MaxUint256.toString());
    console.log("LisUSD approved");
    // approve collateral
    this.Token = await ethers.getContractFactory("ERC20UpgradeableMock");
    const token = this.Token.attach(TOKEN);
    // get balance
    const balance = await token.balanceOf(deployer.address);
    console.log("Balance:", balance)
    const depositAmount = ethers.parseEther('100');
    const borrowAmount = ethers.parseEther('15');
    console.log("Balance:", ethers.parseEther(balance.toString()));
    if (balance < BigInt(depositAmount)) {
        console.error("Not enough balance");
        return;
    }
    console.log("Approving collateral...");
    let tx = await token.approve(INTERACTION, depositAmount);
    await tx.wait();
    console.log("Collateral approved:", depositAmount.toString());
    // deposit collateral
    console.log("Depositing collateral...");
    tx = await interaction.deposit(deployer.address, TOKEN, depositAmount,{ gasLimit: 1000000 });
    await tx.wait();
    console.log("Collateral deposited:", depositAmount.toString());
    // borrow collateral
    console.log("Borrowing collateral...");
    tx = await interaction.borrow(TOKEN, borrowAmount, { gasLimit: 1000000 });
    await tx.wait();
    console.log("Collateral borrowed:", borrowAmount.toString());
    // get borrowed
    const totalBorrowed = await interaction.borrowed(TOKEN, deployer.address);
    // payback collateral
    console.log("Payback collateral...");
    tx = await interaction.payback(TOKEN, totalBorrowed, { gasLimit: 1000000 });
    await tx.wait();
    console.log("Collateral payback success:", totalBorrowed.toString());
    // withdraw collateral
    // get available collateral
    const available = await interaction.locked(TOKEN, deployer.address);
    console.log("Withdraw collateral...")
    await interaction.withdraw(deployer.address, TOKEN, available, { gasLimit: 1000000 });
    console.log("Collateral withdrawn:", available.toString());
    console.log('Finished');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
