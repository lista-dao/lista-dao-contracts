const { upgradeProxy , deployImplementatoin , verifyImpContract} = require("./utils/upgrade_utils")
const proxyAddress = "0x0F412DE8634939533ef056dF543a57134D11B0C7";
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