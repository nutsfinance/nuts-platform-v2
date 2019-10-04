const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentManagerFactory = artifacts.require('./instruments/InstrumentManagerFactory.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const InstrumentV1Manager = artifacts.require('./instruments/InstrumentV1Manager.sol');
const InstrumentV2Manager = artifacts.require('./instruments/InstrumentV2Manager.sol');
const InstrumentV3Manager = artifacts.require('./instruments/InstrumentV3Manager.sol');
const InstrumentEscrow = artifacts.require('./escrow/InstrumentEscrow.sol');
const IssuanceEscrow = artifacts.require('./escrow/IssuanceEscrow.sol');

const Lending = artifacts.require('./instruments/lending/LendingV1.sol');

const deployNutsPlatform = async function(deployer, accounts) {
    // Deploy NUTS token
    // TODO Add proxy to NUTS token
    // let nutsToken = await deployer.deploy(NUTSToken);

    // // Deploy Price Oracle
    // let priceOracle = await deployer.deploy(PriceOracle);

    // let instrumentEscrow = await deployer.deploy(InstrumentEscrow);
    // let issuanceEscrow = await deployer.deploy(IssuanceEscrow);

    let instrumentV1Manager = await deployer.deploy(InstrumentV1Manager);
    let instrumentV2Manager = await deployer.deploy(InstrumentV2Manager);
    let instrumentV3Manager = await deployer.deploy(InstrumentV3Manager);

    // let lending = await deployer.deploy(Lending);

    // // Deploy Instrument Manager Factory
    // let instrumentManagerFactory = await deployer.deploy(InstrumentManagerFactory);

    // // Deploy Instrument Registry
    // let instrumentRegistry = await deployer.deploy(InstrumentRegistry);
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => deployNutsPlatform(deployer, accounts))
    .catch(error => {
    console.log(error);
    process.exit(1);
    });
};