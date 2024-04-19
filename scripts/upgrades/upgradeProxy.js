const { upgradeProxy , deployImplementation , verifyImpContract} = require("./utils/upgrade_utils")
const proxyAddress = "0x61364C8BaCc5CF2e21897D66396C5Ff1c23e32f0";
const contractName = "SnBnbYieldConverterStrategy";

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