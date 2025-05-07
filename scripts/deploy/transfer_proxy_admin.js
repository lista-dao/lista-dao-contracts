const { transferProxyAdminOwner} = require("../upgrades/utils/upgrade_utils")

const main = async () => {
  const proxyAddresses = [
    '0xad9eAAe95617c39019aCC42301a1dCa4ea5b6f65',
    '0xb12fF6FD1885a9Cb2b26302c98092644604B1e92',
    '0x2eeDc4723b1ED2f24afCD9c0e3665061bD2D5642',
    '0xd7E33948e2a43e7C1ec2F19937bf5bf8BbF9BaE8',
    '0x5784e62b4495c7Cc4B09CcD3f206Cc7128449CE0',
    '0xE859f3f6EE5532313C33A02283150E201290F45F',
    '0x2367f2Da6fd39De6944218CC9EC706BCdc9a6918',
    '0xF21B35EdF7A927799b80F09C395C460C3d31D057',
    '0xE514851E324B54f152F7D9631ACe1A0a87248b46',
    '0x876cd9a380Ee7712129b52f8293F6f06056c3104',
    '0x5AaBBBe154C0AFA072e313d46b29592936493b26',
    '0xDF5A8e190CF63D74a4Ec743253fA26D4C7539Be8',
    '0x9DdD9bc74D1abab667097581FAE6Ee8Dd3be5ff2', // BoundValidator
    '0xf3afD82A4071f272F403dC176916141f44E6c750', // ResilientOracle
    '0x873339A8214657175D9B128dDd57A2f2c23256FA', // DynamicDutyCalculator
  ]
  const newOwner = '0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253'
  // transfer proxy admin ownership
  for (let i = 0; i < proxyAddresses.length; i++) {
    await transferProxyAdminOwner(proxyAddresses[i], newOwner)
  }
};

main()
  .then(() => {
    console.log("Success");
  })
  .catch((err) => {
    console.log(err);
  });
