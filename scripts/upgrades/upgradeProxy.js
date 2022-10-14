const { upgradeProxy , deployImplementatoin , verifyImpContract} = require("./utils/upgrade_utils")
const proxyAddress = "0x17a2C89F7D81e031FF0a1e2d64a9C061e57Dfe68";
const contractName = "MasterVault";

const main = async () => {

    // deploy Implementation
    const impAddress = await deployImplementatoin(contractName);

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