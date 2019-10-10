const InstrumentV1Manager = artifacts.require('./instruments/InstrumentV1Manager.sol');
const InstrumentV2Manager = artifacts.require('./instruments/InstrumentV2Manager.sol');
const InstrumentV3Manager = artifacts.require('./instruments/InstrumentV3Manager.sol');
const InstrumentManagerFactory = artifacts.require('./instruments/InstrumentManagerFactory.sol');
const InstrumentManagerInterface = artifacts.require('./instruments/InstrumentManagerInterface.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const StorageFactory = artifacts.require('./storage/StorageFactory.sol');
const ProxyFactory = artifacts.require('./lib/proxy/ProxyFactory.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const LendingV1 = artifacts.require('./instruments/lending/LendingV1.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');

const deployNutsPlatform = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker]) {

    // Deploy Instrument Managers
    let instrumentV1Manager = await deployer.deploy(InstrumentV1Manager);
    let instrumentV2Manager = await deployer.deploy(InstrumentV2Manager);
    let instrumentV3Manager = await deployer.deploy(InstrumentV3Manager);

    // Deploy Instrument Manager Factory
    let instrumentManagerFactory = await deployer.deploy(InstrumentManagerFactory);
    await instrumentManagerFactory.setInstrumentManagerImplementation('version1', instrumentV1Manager.address);
    await instrumentManagerFactory.setInstrumentManagerImplementation('version2', instrumentV2Manager.address);
    await instrumentManagerFactory.setInstrumentManagerImplementation('version3', instrumentV3Manager.address);

    // Deploy NUTS token
    let nutsToken = await deployer.deploy(NUTSToken);

    // Deploy Price Oracle
    let priceOracle = await deployer.deploy(PriceOracle);

    // Deploy Instrument Registry
    let escrowFactory = await deployer.deploy(EscrowFactory);
    let storageFactory = await deployer.deploy(StorageFactory);
    let proxyFactory = await deployer.deploy(ProxyFactory);
    let instrumentRegistry = await deployer.deploy(InstrumentRegistry);
    console.log('Initializing instrument registry...');

    await instrumentRegistry.initialize(owner, 0, 0, nutsToken.address, proxyAdmin, timerOracle,
        priceOracle.address, instrumentManagerFactory.address, escrowFactory.address, storageFactory.address, proxyFactory.address);

    // Deploy LendingV1
    console.log('Deploying lending instrument.');
    let lending = await deployer.deploy(LendingV1, {from: fsp});
    let parametersUtil = await deployer.deploy(ParametersUtil);
    let instrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    console.log('Instrument parameters: ' + instrumentParameters);

    // Activate LendingV1
    await instrumentRegistry.activateInstrument(lending.address, 'version3', instrumentParameters, {from: fsp});
    const instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(lending.address, {from: fsp});
    console.log('Instrument manager address: ' + instrumentManagerAddress);
    const instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    const instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Instrument escrow address: ' + instrumentEscrowAddress);

    // Deploy ERC20 tokens
    const lendingToken = await deployer.deploy(TokenMock);
    const collateralToken = await deployer.deploy(TokenMock);
    await priceOracle.setRate(lendingToken.address, collateralToken.address, 1, 100);
    await priceOracle.setRate(collateralToken.address, lendingToken.address, 100, 1);

    // Create lending issuance.
    const lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, 
        lendingToken.address, 10000, 150, 7, 20, 10000);
    console.log('Lending maker parameters: ' + lendingMakerParameters);
    await instrumentManager.createIssuance(lendingMakerParameters, {from: maker});

    // Deposit principal tokens
    const instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);
    await lendingToken.transfer(maker, 200);
    await lendingToken.approve(instrumentEscrowAddress, 200, {from: maker});
    await instrumentEscrow.depositToken(lendingToken.address, 150, {from: maker});
    const lendingBalance = await instrumentEscrow.getTokenBalance(maker, lendingToken.address);
    console.log(lendingBalance.toNumber());
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => deployNutsPlatform(deployer, accounts))
    .catch(error => {
    console.log(error);
    process.exit(1);
    });
};