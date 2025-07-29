import {ethers} from "hardhat";

const hre = require("hardhat");
const {upgrades} = require("hardhat");

const cdpLiquidator = "0x90085cA23203d021ce7ed7373a32d11E7edd7448";
const tokens = [
    "0x563282106A5B0538f8673c787B3A16D3Cc1DbF1a",
    "0x6C813D1d114d0caBf3F82f9E910BC29fE7f96451",
    "0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B",
    "0xa2E3356610840701BDf5611a53974510Ae27E2e1",
    "0x26c5e01524d2e6280a48f2c50ff6de7e52e9611c",
    "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c",
    "0x55d398326f99059fF775485246999027B3197955",
    "0xc5f0f7b66764f6ec8c8dff7ba683102295e16409",
    "0x4aae823a6a0b376De6A78e74eCC5b079d38cBCf7",
    "0x1346b618dc92810ec74163e4c27004c921d446a5",
    "0x80137510979822322193FC997d400D5A6C747bf7",
    "0x7788a3538c5fc7f9c7c8a74eac4c898fc8d87d92",
    "0xc6f28a668b7c18f921ccba4adc3d8db72bff0fe2",
    "0x4510aa2b3efd13bBFD78C9BfdE764F224ecc7f50",
    "0x581fa684d0ec11ccb46b1d92f1f24c8a3f95c0ca",
    "0x7dc91cbd6cb5a3e6a95eed713aa6bf1d987146c8",
    "0x5a110fc00474038f6c02e89c707d638602ea44b5",
    "0x917af46b3c3c6e1bb7286b9f59637fb7c65851fb",
    "0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d"
];

const pairs = [
    "0x111111125421cA6dc452d289314280a0f8842A65"
];

async function main() {
  const [deployer] = await ethers.getSigners();
  const CDPLiquidator = await hre.ethers.getContractAt("CDPLiquidator", cdpLiquidator, deployer)

  for (const token of tokens) {
    await CDPLiquidator.setTokenWhitelist(token, true);
    console.log(`Token: ${token} whitelisted in CDPLiquidator`);
  }
  for (const pair of pairs) {
    await CDPLiquidator.setPairWhitelist(pair, true);
    console.log(`Pair: ${pair} whitelisted in CDPLiquidator`);
  }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
