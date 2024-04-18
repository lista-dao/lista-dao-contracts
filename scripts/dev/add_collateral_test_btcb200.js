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
    let TOKEN = "0x4Bb08858bc554043C157B7d7138F0cFf98Be66DC";
    let INTERACTION = "0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4";
    let AUCTION_PROXY = '0x052A298354D59BA5DA8D2E558E74b750a8073D86'

    if (hre.network.name === "bsc_testnet") {
        INTERACTION = "0xb7A5999AEaE17C37d07ac4b34e56757c96387c84";
        if (!AUCTION_PROXY) {
            // deploy AuctionProxy
            const AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");
            const auctionProxy = await AuctionProxy.deploy();
            await auctionProxy.waitForDeployment();
            AUCTION_PROXY = await auctionProxy.getAddress();
            //verify
            await hre.run('verify:verify', {address: AUCTION_PROXY})
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
    tx = await interaction.deposit(deployer.address, TOKEN, depositAmount);
    await tx.wait();
    console.log("Collateral deposited:", depositAmount.toString());
    // borrow collateral
    console.log("Borrowing collateral...");
    tx = await interaction.borrow(TOKEN, borrowAmount);
    await tx.wait();
    console.log("Collateral borrowed:", borrowAmount.toString());
    // get borrowed
    const totalBorrowed = await interaction.borrowed(TOKEN, deployer.address);
    // payback collateral
    console.log("Payback collateral...");
    tx = await interaction.payback(TOKEN, totalBorrowed);
    await tx.wait();
    console.log("Collateral payback success:", totalBorrowed.toString());
    // withdraw collateral
    // get available collateral
    const available = await interaction.free(TOKEN, deployer.address);
    console.log("Withdraw collateral...")
    await interaction.withdraw(deployer.address, TOKEN, available);

    console.log("Collateral withdrawn:", available.toString());
    console.log('Finished');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
      console.error(error);
      process.exit(1);
  });
