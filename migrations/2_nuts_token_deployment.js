const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');

const deployNutsPlatform = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) {
    // Deploy NUTS token
    let nutsToken = await deployer.deploy(NUTSToken);
    console.log("NUTSToken address: " + nutsToken.address);

    let token1 = await deployer.deploy(TokenMock);
    console.log("TokenMock 1 address: " + token1.address);

    let token2 = await deployer.deploy(TokenMock);
    console.log("TokenMock 2 address: " + token2.address);
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => deployNutsPlatform(deployer, accounts))
    .catch(error => {
      console.log(error);
      process.exit(1);
    });
};
