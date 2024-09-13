import { ethers } from "hardhat";

async function main() {
  const DynamicDutyCalculator = await ethers.getContractFactory(
    "DynamicDutyCalculator"
  );
  const dutyCalculator = await DynamicDutyCalculator.deploy();
  await dutyCalculator.waitForDeployment();
  const dutyCalculatorAddress = await dutyCalculator.getAddress();
  console.log(
    "DynamicDutyCalculator impl contract deployed at: ",
    dutyCalculatorAddress
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
