const { upgradeProxy , deployImplementation , verifyImpContract} = require("./utils/upgrade_utils")
const proxyAddress = "0x6aE8ee5892DEcC80EC2FADdd4A87d1892254B57f";
const contractName = "BnbxYieldConverterStrategy";

const main = async () => {

  console.log("Upgrading CeVaultV2...");
  const ceVaultImpAddress = await deployImplementation("CerosRouter");

    // upgrade Proxy
    // await upgradeProxy(proxyAddress, impAddress);

    await verifyImpContract(ceVaultImpAddress);    
};

main()
  .then(() => {
    console.log("Success");
  })
  .catch((err) => {
    console.log(err);
  });