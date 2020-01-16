const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const assert = require('assert');
const LogParser = require(__dirname + "/LogParser.js");

const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
const InstrumentManager = artifacts.require('./instrument/InstrumentManager.sol');
const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const Borrowing = artifacts.require('./instrument/borrowing/Borrowing.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const IssuanceEscrowInterface = artifacts.require('./escrow/IssuanceEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const NUTSTokenMock = artifacts.require('./mock/NUTSTokenMock.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const IssuanceEscrow = artifacts.require('./escrow/IssuanceEscrow.sol');
const InstrumentEscrow = artifacts.require('./escrow/InstrumentEscrow.sol');

contract('InstrumentRegistry', ([owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) => {
  it('new instrument deposit cost ', async () => {
    // Deploy Instrument Managers
    let instrumentManagerFactory = await InstrumentManagerFactory.new();

    // Deploy NUTS token
    let nutsToken = await NUTSTokenMock.new();

    // Deploy Price Oracle
    let priceOracle = await PriceOracle.new();

    // Deploy Escrow Factory
    let escrowFactory = await EscrowFactory.new();

    // Deploy Instrument Registry
    let instrumentRegistry = await InstrumentRegistry.new(instrumentManagerFactory.address,
        1, 0, nutsToken.address, priceOracle.address, escrowFactory.address);

    let parametersUtil = await ParametersUtil.new();

    console.log('Deploying borrowing instrument.');
    let borrowing = await Borrowing.new({from: fsp});
    let borrowingInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);
    await nutsToken.transfer(fsp, 2);
    await nutsToken.approve(instrumentRegistry.address, 1, {from: fsp});
    let txn = await instrumentRegistry.activateInstrument(borrowing.address, borrowingInstrumentParameters, {from: fsp});
    let abis = [].concat(NUTSTokenMock.abi, InstrumentRegistry.abi);
    let events = LogParser.logParser(txn.receipt.rawLogs, abis);
    let receipt = {logs: events};
    expectEvent(receipt, 'Transfer', {
      from: fsp,
      to: instrumentRegistry.address,
      value: '1'
    });
  }),
  it('new issuance deposit cost ', async () => {
    // Deploy Instrument Managers
    let instrumentManagerFactory = await InstrumentManagerFactory.new();

    // Deploy NUTS token
    let nutsToken = await NUTSTokenMock.new();

    // Deploy Price Oracle
    let priceOracle = await PriceOracle.new();

    // Deploy Escrow Factory
    let escrowFactory = await EscrowFactory.new();

    // Deploy Instrument Registry
    let instrumentRegistry = await InstrumentRegistry.new(instrumentManagerFactory.address,
        0, 1, nutsToken.address, priceOracle.address, escrowFactory.address);

    let parametersUtil = await ParametersUtil.new();

    console.log('Deploying borrowing instrument.');
    let borrowing = await Borrowing.new({from: fsp});
    let borrowingInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);
    await instrumentRegistry.activateInstrument(borrowing.address, borrowingInstrumentParameters, {from: fsp});

    let instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(1, {from: fsp});
    console.log('Borrowing instrument manager address: ' + instrumentManagerAddress);
    let instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    let instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Borrowing instrument escrow address: ' + instrumentEscrowAddress);
    let instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);

    // Deploy ERC20 tokens
    let borrowingToken = await TokenMock.new();
    let collateralToken = await TokenMock.new();
    await priceOracle.setRate(borrowingToken.address, collateralToken.address, 1, 100);
    await priceOracle.setRate(collateralToken.address, borrowingToken.address, 100, 1);

    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});
    await nutsToken.transfer(maker1, 1);
    await nutsToken.approve(instrumentEscrowAddress, 1, {from: maker1});
    await instrumentEscrow.depositToken(nutsToken.address, 1, {from: maker1});
    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let txn = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let abis = [].concat(NUTSTokenMock.abi, InstrumentRegistry.abi);
    let events = LogParser.logParser(txn.receipt.rawLogs, abis);
    let receipt = {logs: events};
    expectEvent(receipt, 'Transfer', {
      from: instrumentEscrowAddress,
      to: instrumentManagerAddress,
      value: '1'
    });
  })
});
