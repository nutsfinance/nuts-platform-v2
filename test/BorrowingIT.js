const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const assert = require('assert');
const SolidityEvent = require("web3");
const LogParser = require(__dirname + "/LogParser.js");
const GoogleSheets = require(__dirname + "/GoogleSheets.js");
const protobuf = require(__dirname + "/../protobuf-js-messages");
const LineItems = require(__dirname + "/LineItems.js");
const custodianAddress = "0xDbE7A2544eeFfec81A7D898Ac08075e0D56FEac6";

const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
const InstrumentManager = artifacts.require('./instrument/InstrumentManager.sol');
const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const Borrowing = artifacts.require('./instrument/borrowing/Borrowing.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const IssuanceEscrowInterface = artifacts.require('./escrow/IssuanceEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');
const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const IssuanceEscrow = artifacts.require('./escrow/IssuanceEscrow.sol');
const InstrumentEscrow = artifacts.require('./escrow/InstrumentEscrow.sol');

let parametersUtil;
let collateralToken;
let borrowingToken;
let instrumentEscrow;
let instrumentManager;
let instrumentEscrowAddress;
let instrumentManagerAddress;
let borrowing;

contract('Borrowing', ([owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) => {
  beforeEach(async () => {
    // Deploy Instrument Managers
    let instrumentManagerFactory = await InstrumentManagerFactory.new();

    // Deploy NUTS token
    let nutsToken = await NUTSToken.new();

    // Deploy Price Oracle
    let priceOracle = await PriceOracle.new();

    // Deploy Escrow Factory
    let escrowFactory = await EscrowFactory.new();

    // Deploy Instrument Registry
    let instrumentRegistry = await InstrumentRegistry.new(instrumentManagerFactory.address,
        0, 0, nutsToken.address, priceOracle.address, escrowFactory.address);

    parametersUtil = await ParametersUtil.new();

    console.log('Deploying borrowing instrument.');
    borrowing = await Borrowing.new({from: fsp});
    let borrowingInstrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    // Activate Borrowing Instrument
    await instrumentRegistry.activateInstrument(borrowing.address, borrowingInstrumentParameters, {from: fsp});
    instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(borrowing.address, {from: fsp});
    console.log('Borrowing instrument manager address: ' + instrumentManagerAddress);
    instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Borrowing instrument escrow address: ' + instrumentEscrowAddress);
    instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);

    // Deploy ERC20 tokens
    borrowingToken = await TokenMock.new();
    collateralToken = await TokenMock.new();
    await priceOracle.setRate(borrowingToken.address, collateralToken.address, 1, 100);
    await priceOracle.setRate(collateralToken.address, borrowingToken.address, 100, 1);
    console.log("Borrowing token address:" + borrowingToken.address);
    console.log("Collateral token address:" + collateralToken.address);
    console.log("maker1: " + maker1);
    console.log("taker1: " + taker1);
  }),
  it('integration tests', async () => {
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
    await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker2});

    // Deposit borrowing tokens to Borrowing Instrument Escrow
    await borrowingToken.transfer(taker2, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker2});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker2});

    // Engage borrowing issuance
    await instrumentManager.engageIssuance(2, '0x0', {from: taker2});
  })
});
