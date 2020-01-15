const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');

const deployNutsPlatform = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) {

    // Deploy Instrument Managers
    let instrumentManagerFactory = await deployer.deploy(InstrumentManagerFactory);
    let nutsToken = await NUTSToken.deployed();
    // Deploy Price Oracle
    let priceOracle = await deployer.deploy(PriceOracle);
    // Deploy Escrow Factory
    let escrowFactory = await deployer.deploy(EscrowFactory);
    // Deploy Instrument Registry
    let instrumentRegistry = await deployer.deploy(InstrumentRegistry, instrumentManagerFactory.address,
        0, 0, nutsToken.address, priceOracle.address, escrowFactory.address);
    const parametersUtil = await deployer.deploy(ParametersUtil);
    console.log("InstrumentManagerFactory address: " + instrumentManagerFactory.address);
    console.log("PriceOracle address: " + priceOracle.address);
    console.log("EscrowFactory address: " + escrowFactory.address);
    console.log("InstrumentRegistry address: " + instrumentRegistry.address);
    console.log("ParametersUtil address: " + parametersUtil.address);
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => deployNutsPlatform(deployer, accounts))
    .catch(error => {
      console.log(error);
      process.exit(1);
    });
};
