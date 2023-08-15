const { upgradeProxy , deployImplementation , verifyImpContract} = require("./utils/upgrade_utils")
const proxyAddress = "0x8e70A9cb4E33207003CDdd142f93576503BE09f7";
const contractName = "MasterVault";

const main = async () => {

    // deploy Implementation
    const impAddress = await deployImplementation(contractName);

    // upgrade Proxy
    await upgradeProxy(proxyAddress, impAddress);

    console.log("Verifying Imp contract...")
    await verifyImpContract(impAddress);
    
};

main()
  .then(() => {
    console.log("Success");
  })
  .catch((err) => {
    console.log(err);
  });