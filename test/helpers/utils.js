"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const hardhat_1 = require("hardhat");
const advanceTime = async (seconds) => {
    await hardhat_1.network.provider.send("evm_increaseTime", [seconds]);
    await hardhat_1.network.provider.send("evm_mine");
};
const toWad = (num) => {
    return hardhat_1.ethers.parseUnits(num, 18);
};
const toRay = (num) => {
    return hardhat_1.ethers.parseUnits(num, 27);
};
const toRad = (num) => {
    return hardhat_1.ethers.parseUnits(num, 45);
};
const printSale = (sale) => {
    // uint256 pos;  // Index in active array
    // uint256 tab;  // Usb to raise       [rad]
    // uint256 lot;  // collateral to sell [wad]
    // address usr;  // Liquidated CDP
    // uint96  tic;  // Auction start time
    // uint256 top;  // Starting price     [ray]
    console.log("pos ->", sale.pos.toString());
    console.log("tab ->", sale.tab.toString());
    console.log("lot ->", sale.lot.toString());
    console.log("usr ->", sale.usr.toString());
    console.log("tic ->", sale.tic.toString());
    console.log("top ->", sale.top.toString());
};
module.exports = {
    toWad,
    toRay,
    toRad,
    advanceTime,
    printSale,
};
