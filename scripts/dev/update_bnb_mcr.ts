import { ethers, upgrades } from "hardhat";

const SPOTTER = "0xa2882B6AC7cBA1b8784BF5D72F38CF0E6416263e";

const BNB_CLIPPER = "0x14DD6c86d24A72b42648D9a642318375A26ed108";
const BNB_MAT = "1200000000000000000000000000"; // 120% mcr
const BNB_ILK =
  "0x636541424e426300000000000000000000000000000000000000000000000000";
const TAU = "3600"; // 1 hour
const BNB_TAIL = "1200"; // 20 minutes elapsed before reset

//////////// Adjust BNB MCR ////////////
/// 1. deploy LinearDecrease contract
/// 2. set tau to 1 hours
/// 3. set Clipper calc to new LinearDecrease
/// 4. set Clipper mat to new MCR
/// 5. verify LinearDecrease contract
async function main() {
  const Abaci = await ethers.getContractFactory("LinearDecrease");
  const abaci = await upgrades.deployProxy(Abaci, []);
  await abaci.waitForDeployment();

  console.log("LinearDecrease deployed to:", abaci.target);

  await abaci.file(ethers.encodeBytes32String("tau"), TAU);

  const Clipper = await ethers.getContractFactory("Clipper");
  const clipper = Clipper.attach(BNB_CLIPPER);
  await clipper["file(bytes32,address)"](
    ethers.encodeBytes32String("calc"),
    abaci.target
  );
  await clipper["file(bytes32,uint256)"](
    ethers.encodeBytes32String("tail"),
    BNB_TAIL
  );

  const Spotter = await ethers.getContractFactory("Spotter");
  const spotter = Spotter.attach(SPOTTER);
  await spotter["file(bytes32,bytes32,uint256)"](
    BNB_ILK,
    ethers.encodeBytes32String("mat"),
    BNB_MAT
  );

  const { mat: newMat } = await spotter.ilks(BNB_ILK);

  console.log("tau set to: ", (await abaci.tau()).toString());
  console.log("Clipper calc set to: ", (await clipper.calc()).toString());
  console.log("Clipper tail set to: ", (await clipper.tail()).toString());
  console.log("Spotter mat set to: ", newMat.toString());

  await run("verify:verify", {
    address: abaci.target,
    constructorArguments: [],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
