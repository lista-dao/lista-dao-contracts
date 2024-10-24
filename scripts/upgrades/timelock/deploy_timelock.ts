import { ethers } from "hardhat";

const admin = "0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06";
const minDelay = "60"; // 60 seconds
const proposers = [admin];
const executors = [admin];

// Proxy and ProxyAdmin addresses
const proxy = "0x3Cf187f30A64fd4357f4EC8Cc133E5AFFA5dB483";
const proxyAdmin = "0x867B15a48127a3d766d53B38a8630b93D2Afb791";
const newImplementation = "0x5BC42792F48039034595949A335D3e7dd2EdeC91";

async function main() {
  // 1. Deploy TimeLock contract
  const TimeLock = await ethers.getContractFactory("TimeLock");
  const timelock = await TimeLock.deploy(minDelay, proposers, executors, admin);
  await timelock.waitForDeployment();
  // TimeLock deployed to: 0x54fA4aeca37BC354f79b3E002E111D2844635bfC
  console.log("TimeLock deployed to:", timelock.target);

  await run("verify:verify", {
    address: timelock.target,
    constructorArguments: [minDelay, proposers, executors, admin],
    contract: "contracts/upgrade/TimeLock.sol:TimeLock",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
