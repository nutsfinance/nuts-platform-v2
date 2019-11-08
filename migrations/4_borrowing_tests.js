const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const Borrowing = artifacts.require('./instrument/borrowing/Borrowing.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');

const runBorrowingTestCases = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) {
    console.log('Running Borrowing Test Cases...');
    const priceOracle = await PriceOracle.deployed();
    const instrumentRegistry = await InstrumentRegistry.deployed();
    const borrowing = await Borrowing.deployed();
    const parametersUtil = await ParametersUtil.deployed();

    // Deploy ERC20 tokens
    const borrowingToken = await deployer.deploy(TokenMock);
    const collateralToken = await deployer.deploy(TokenMock);
    await priceOracle.setRate(borrowingToken.address, collateralToken.address, 1, 100);
    await priceOracle.setRate(collateralToken.address, borrowingToken.address, 100, 1);

    const instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(borrowing.address, {from: fsp});
    console.log('Instrument manager address: ' + instrumentManagerAddress);
    const instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    const instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Instrument escrow address: ' + instrumentEscrowAddress);
    const instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);
    let borrowingMakerParameters;

    /**************************** Borrowing Issuance 1 *****************************************/
    console.log('Creating Borrowing Issuance 1...');
    // Deposit collateral tokens to Borrowing Instrument Escrow
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    // Create borrowing issuance.
    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address, 
        borrowingToken.address, 10000, 20000, 20, 10000);
    await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});

    // Deposit borrowing tokens to Borrowing Instrument Escrow
    await borrowingToken.transfer(taker1, 10000);
    await borrowingToken.approve(instrumentEscrowAddress, 10000, {from: taker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 10000, {from: taker1});

    // Engage borrowing issuance
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});

    /**************************** Borrowing Issuance 2 *****************************************/
    console.log('Creating Borrowing Issuance 2...');
    // Deposit collateral tokens to Borrowing Instrument Escrow
    await collateralToken.transfer(maker2, 3000000);
    await collateralToken.approve(instrumentEscrowAddress, 3000000, {from: maker2});
    await instrumentEscrow.depositToken(collateralToken.address, 3000000, {from: maker2});

    // Create borrowing issuance.
    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address, 
        borrowingToken.address, 15000, 20000, 20, 10000);
    await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});

    // Deposit borrowing tokens to Borrowing Instrument Escrow
    await borrowingToken.transfer(taker2, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker2});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker2});

    // Engage borrowing issuance
    await instrumentManager.engageIssuance(2, '0x0', {from: taker2});
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => runBorrowingTestCases(deployer, accounts))
    .catch(error => {
    console.log(error);
    process.exit(1);
    });
};