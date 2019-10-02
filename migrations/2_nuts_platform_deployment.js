const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentManagerFactory = artifacts.require('./instruments/InstrumentManagerFactory.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const InstrumentV1Manager = artifacts.require('./instruments/InstrumentV1Manager.sol');
const InstrumentEscrow = artifacts.require('./escrow/InstrumentEscrow.sol');
const IssuanceEscrow = artifacts.require('./escrow/IssuanceEscrow.sol');

const deployNutsPlatform = async function(deployer, accounts) {
    // Deploy NUTS token
    // TODO Add proxy to NUTS token
    let nutsToken = await deployer.deploy(NUTSToken);

    // Deploy Price Oracle
    let priceOracle = await deployer.deploy(PriceOracle);

    let instrumentEscrow = await deployer.deploy(InstrumentEscrow);
    let issuanceEscrow = await deployer.deploy(IssuanceEscrow);

    // let instrumentV1Manager = await deployer.deploy(InstrumentV1Manager);
    // // Deploy Instrument Manager Factory
    // let instrumentManagerFactory = await deployer.deploy(InstrumentManagerFactory);

    // // Deploy Instrument Registry
    let instrumentRegistry = await deployer.deploy(InstrumentRegistry);
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => deployNutsPlatform(deployer, accounts))
    .catch(error => {
    console.log(error);
    process.exit(1);
    });
};