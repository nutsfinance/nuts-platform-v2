const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const Lending = artifacts.require('./instrument/lending/Lending.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');

const runLendingTestCases = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) {
    console.log('Running Lending Test Cases...');
    const priceOracle = await PriceOracle.deployed();
    const instrumentRegistry = await InstrumentRegistry.deployed();
    const lending = await Lending.deployed();
    const parametersUtil = await ParametersUtil.deployed();

    // Deploy ERC20 tokens
    const lendingToken = await deployer.deploy(TokenMock);
    const collateralToken = await deployer.deploy(TokenMock);
    await priceOracle.setRate(lendingToken.address, collateralToken.address, 1, 100);
    await priceOracle.setRate(collateralToken.address, lendingToken.address, 100, 1);

    const instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(lending.address, {from: fsp});
    console.log('Instrument manager address: ' + instrumentManagerAddress);
    const instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    const instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Instrument escrow address: ' + instrumentEscrowAddress);
    const instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);
    let lendingMakerParameters;

    /**************************** Lending Issuance 1 *****************************************/
    console.log('Creating Lending Issuance 1...');
    // Deposit principal tokens to Lending Instrument Escrow
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});

    // Create lending issuance.
    console.log('Create issuance');
    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 20, 10000);
    await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1});

    // Engage lending issuance
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});

    /**************************** Lending Issuance 2 *****************************************/
    console.log('Creating Lending Issuance 2...');
    // Deposit principal tokens to Lending Instrument Escrow
    await lendingToken.transfer(maker2, 10000);
    await lendingToken.approve(instrumentEscrowAddress, 10000, {from: maker2});
    await instrumentEscrow.depositToken(lendingToken.address, 10000, {from: maker2});

    // Create lending issuance.
    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 10000, 15000, 12, 50000);
    await instrumentManager.createIssuance(lendingMakerParameters, {from: maker2});

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker2, 1500000);
    await collateralToken.approve(instrumentEscrowAddress, 1500000, {from: taker2});
    await instrumentEscrow.depositToken(collateralToken.address, 1500000, {from: taker2});

    // Engage lending issuance
    await instrumentManager.engageIssuance(2, '0x0', {from: taker2});

    /**************************** Lending Issuance 3 *****************************************/
    console.log('Creating Lending Issuance 3...');
    // Deposit principal tokens to Lending Instrument Escrow
    await lendingToken.transfer(maker3, 40000);
    await lendingToken.approve(instrumentEscrowAddress, 40000, {from: maker3});
    await instrumentEscrow.depositToken(lendingToken.address, 40000, {from: maker3});

    // Create lending issuance.
    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 40000, 10000, 30, 10000);
    await instrumentManager.createIssuance(lendingMakerParameters, {from: maker3});

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker3, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker3});
    await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker3});

    // Engage lending issuance
    await instrumentManager.engageIssuance(3, '0x0', {from: taker3});

    /**************************** Lending Issuance 4 *****************************************/
    console.log('Creating Lending Issuance 4...');
    // Deposit principal tokens to Lending Instrument Escrow
    await lendingToken.transfer(maker1, 30000);
    await lendingToken.approve(instrumentEscrowAddress, 30000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 30000, {from: maker1});

    // Create lending issuance.
    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 30000, 15000, 20, 20000);
    await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker2, 4500000);
    await collateralToken.approve(instrumentEscrowAddress, 4500000, {from: taker2});
    await instrumentEscrow.depositToken(collateralToken.address, 4500000, {from: taker2});

    // Engage lending issuance
    await instrumentManager.engageIssuance(4, '0x0', {from: taker2});

    /**************************** Lending Issuance 5 *****************************************/
    console.log('Creating Lending Issuance 5...');
    // Deposit principal tokens to Lending Instrument Escrow
    await lendingToken.transfer(maker1, 50000);
    await lendingToken.approve(instrumentEscrowAddress, 50000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 50000, {from: maker1});

    // Create lending issuance.
    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 50000, 15000, 50, 10000);
    await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker3, 7500000);
    await collateralToken.approve(instrumentEscrowAddress, 7500000, {from: taker3});
    await instrumentEscrow.depositToken(collateralToken.address, 7500000, {from: taker3});

    // Engage lending issuance
    await instrumentManager.engageIssuance(5, '0x0', {from: taker3});

};

module.exports = function(deployer, network, accounts) {
deployer
    // .then(() => runLendingTestCases(deployer, accounts))
    .then(() => console.log("a"))
    .catch(error => {
      console.log(error);
      process.exit(1);
    });
};
