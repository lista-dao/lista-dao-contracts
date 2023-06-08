const { upgradeProxy , deployImplementation , verifyImpContract} = require("./utils/upgrade_utils")
const proxyAddress = "0xf8795cc4Fa58c5D831b0a4D6de8d7dE2c2a6717E";
const contractName = "StkBnbStrategy";

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