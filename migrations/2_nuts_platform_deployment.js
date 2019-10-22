const InstrumentV1ManagerFactory = artifacts.require('./instrument/v1/InstrumentV1ManagerFactory.sol');
const InstrumentV2ManagerFactory = artifacts.require('./instrument/v2/InstrumentV2ManagerFactory.sol');
const InstrumentV3ManagerFactory = artifacts.require('./instrument/v3/InstrumentV3ManagerFactory.sol');
const InstrumentManagerInterface = artifacts.require('./instruments/InstrumentManagerInterface.sol');
const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const StorageFactory = artifacts.require('./storage/StorageFactory.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const Lending = artifacts.require('./instruments/lending/Lending.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');

const deployNutsPlatform = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker]) {

    // Deploy Storage Factory
    let storageFactory = await deployer.deploy(StorageFactory);

    // Deploy Instrument Managers
    let instrumentV1ManagerFactory = await deployer.deploy(InstrumentV1ManagerFactory);
    let instrumentV2ManagerFactory = await deployer.deploy(InstrumentV2ManagerFactory, storageFactory.address);
    let instrumentV3ManagerFactory = await deployer.deploy(InstrumentV3ManagerFactory);

    // Deploy NUTS token
    let nutsToken = await deployer.deploy(NUTSToken);

    // Deploy Price Oracle
    let priceOracle = await deployer.deploy(PriceOracle);

    // Deploy Escrow Factory
    let escrowFactory = await deployer.deploy(EscrowFactory);

    // Deploy Instrument Registry
    let instrumentRegistry = await deployer.deploy(InstrumentRegistry, 0, 0, nutsToken.address, priceOracle.address, escrowFactory.address);
    
    // Registry Instrument Manager Factories
    await instrumentRegistry.setInstrumentManagerFactory('version1', instrumentV1ManagerFactory.address);
    await instrumentRegistry.setInstrumentManagerFactory('version2', instrumentV2ManagerFactory.address);
    await instrumentRegistry.setInstrumentManagerFactory('version3', instrumentV3ManagerFactory.address);

    // Deploy LendingV1
    console.log('Deploying lending instrument.');
    let lending = await deployer.deploy(Lending, {from: fsp});
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

    // Deposit principal tokens
    const instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);
    await lendingToken.transfer(maker, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker});
    await instrumentEscrow.depositToken(lendingToken.address, 15000, {from: maker});
    const lendingBalance = await instrumentEscrow.getTokenBalance(maker, lendingToken.address);
    console.log(lendingBalance.toNumber());

    // Create lending issuance.
    const lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, 
        lendingToken.address, 10000, 15000, 20, 10000);
    console.log('Lending maker parameters: ' + lendingMakerParameters);
    await instrumentManager.createIssuance(lendingMakerParameters, {from: maker});
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => deployNutsPlatform(deployer, accounts))
    .catch(error => {
    console.log(error);
    process.exit(1);
    });
};