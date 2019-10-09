const InstrumentV1Manager = artifacts.require('./instruments/InstrumentV1Manager.sol');
const InstrumentV2Manager = artifacts.require('./instruments/InstrumentV2Manager.sol');
const InstrumentV3Manager = artifacts.require('./instruments/InstrumentV3Manager.sol');
const InstrumentManagerFactory = artifacts.require('./instruments/InstrumentManagerFactory.sol');
const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const StorageFactory = artifacts.require('./storage/StorageFactory.sol');
const ProxyFactory = artifacts.require('./lib/proxy/ProxyFactory.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const LendingV1 = artifacts.require('./instruments/lending/LendingV1.sol');

const deployNutsPlatform = async function(deployer, accounts) {

    // Deploy Instrument Managers
    let instrumentV1Manager = await deployer.deploy(InstrumentV1Manager);
    let instrumentV2Manager = await deployer.deploy(InstrumentV2Manager);
    let instrumentV3Manager = await deployer.deploy(InstrumentV3Manager);

    // Deploy Instrument Manager Factory
    let instrumentManagerFactory = await deployer.deploy(InstrumentManagerFactory);
    await instrumentManagerFactory.setInstrumentManagerImplementation(web3.utils.fromAscii('version1'), instrumentV1Manager.address);
    await instrumentManagerFactory.setInstrumentManagerImplementation(web3.utils.fromAscii('version2'), instrumentV2Manager.address);
    await instrumentManagerFactory.setInstrumentManagerImplementation(web3.utils.fromAscii('version3'), instrumentV3Manager.address);

    // Deploy NUTS token
    let nutsToken = await deployer.deploy(NUTSToken);

    // Deploy Price Oracle
    let priceOracle = await deployer.deploy(PriceOracle);

    // Deploy Instrument Registry
    let escrowFactory = await deployer.deploy(EscrowFactory);
    let storageFactory = await deployer.deploy(StorageFactory);
    let proxyFactory = await deployer.deploy(ProxyFactory);
    let instrumentRegistry = await deployer.deploy(InstrumentRegistry);
    await instrumentRegistry.initialize(accounts[0], 0, 0, nutsToken.address, accounts[0], accounts[1],
        priceOracle.address, instrumentManagerFactory.address, escrowFactory.address, storageFactory.address, proxyFactory.address);

    // Deploy LendingV1
    let lending = await deployer.deploy(LendingV1);
};


module.exports = function(deployer, network, accounts) {
deployer
    .then(() => deployNutsPlatform(deployer, accounts))
    .catch(error => {
    console.log(error);
    process.exit(1);
    });
};