const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const Saving = artifacts.require('./instrument/saving/Saving.sol');
const Lending = artifacts.require('./instrument/lending/Lending.sol');
const Borrowing = artifacts.require('./instrument/borrowing/Borrowing.sol');
const SpotSwap = artifacts.require('./instrument/swap/SpotSwap.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');

const deployNutsPlatform = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) {

    // Deploy Instrument Managers
    let instrumentManagerFactory = await deployer.deploy(InstrumentManagerFactory);

    // Deploy NUTS token
    let nutsToken = await deployer.deploy(NUTSToken);

    // Deploy Price Oracle
    let priceOracle = await deployer.deploy(PriceOracle);

    // Deploy Escrow Factory
    let escrowFactory = await deployer.deploy(EscrowFactory);

    // Deploy Instrument Registry
    let instrumentRegistry = await deployer.deploy(InstrumentRegistry, instrumentManagerFactory.address,
        0, 0, nutsToken.address, priceOracle.address, escrowFactory.address);

    const parametersUtil = await deployer.deploy(ParametersUtil);

    // // Deploy ERC20 tokens
    // const lendingToken = await deployer.deploy(TokenMock);
    // const collateralToken = await deployer.deploy(TokenMock);
    // await priceOracle.setRate(lendingToken.address, collateralToken.address, 1, 100);
    // await priceOracle.setRate(collateralToken.address, lendingToken.address, 100, 1);

    /**
     * Saving Instrument deployment
     */
    console.log('Deploying saving instrument.');
    let saving = await deployer.deploy(Saving, {from: fsp});
    let savingInstrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    // Activate Saving Instrument
    await instrumentRegistry.activateInstrument(saving.address, savingInstrumentParameters, {from: fsp});
    const savingInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(saving.address, {from: fsp});
    console.log('Saving instrument manager address: ' + savingInstrumentManagerAddress);
    const savingInstrumentManager = await InstrumentManagerInterface.at(savingInstrumentManagerAddress);
    console.log('Get saving instrument');
    const savingInstrumentEscrowAddress = await savingInstrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Saving instrument escrow address: ' + savingInstrumentEscrowAddress);

    /**
     * Lending Instrument deployment
     */
    console.log('Deploying lending instrument.');
    let lending = await deployer.deploy(Lending, {from: fsp});
    let lendingInstrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    // Activate Lending Instrument
    await instrumentRegistry.activateInstrument(lending.address, lendingInstrumentParameters, {from: fsp});
    const lendingInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(lending.address, {from: fsp});
    console.log('Lending instrument manager address: ' + lendingInstrumentManagerAddress);
    const lendingInstrumentManager = await InstrumentManagerInterface.at(lendingInstrumentManagerAddress);
    const lendingInstrumentEscrowAddress = await lendingInstrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Lending instrument escrow address: ' + lendingInstrumentEscrowAddress);

    /**
     * Borrowing Instrument deployment
     */
    console.log('Deploying borrowing instrument.');
    let borrowing = await deployer.deploy(Borrowing, {from: fsp});
    let borrowingInstrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    // Activate Borrowing Instrument
    await instrumentRegistry.activateInstrument(borrowing.address, borrowingInstrumentParameters, {from: fsp});
    const borrowingInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(borrowing.address, {from: fsp});
    console.log('Borrowing instrument manager address: ' + borrowingInstrumentManagerAddress);
    const borrowingInstrumentManager = await InstrumentManagerInterface.at(borrowingInstrumentManagerAddress);
    const borrowingInstrumentEscrowAddress = await borrowingInstrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Borrowing instrument escrow address: ' + borrowingInstrumentEscrowAddress);

    /**
     * Spot Swap Instrument deployment
     */
    console.log('Deploying spot swap instrument.');
    let swap = await deployer.deploy(SpotSwap, {from: fsp});
    let swapInstrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    // Activate Spot Swap Instrument
    await instrumentRegistry.activateInstrument(swap.address, swapInstrumentParameters, {from: fsp});
    const swapInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(swap.address, {from: fsp});
    console.log('Spot swap instrument manager address: ' + swapInstrumentManagerAddress);
    const swapInstrumentManager = await InstrumentManagerInterface.at(swapInstrumentManagerAddress);
    const swapInstrumentEscrowAddress = await swapInstrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Spot swap instrument escrow address: ' + swapInstrumentEscrowAddress);
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => deployNutsPlatform(deployer, accounts))
    .catch(error => {
    console.log(error);
    process.exit(1);
    });
};
