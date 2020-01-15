const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const assert = require('assert');
const SolidityEvent = require("web3");
const LogParser = require(__dirname + "/LogParser.js");
const LineItems = require(__dirname + "/LineItems.js");
const protobuf = require(__dirname + "/../protobuf-js-messages");
const custodianAddress = "0xDbE7A2544eeFfec81A7D898Ac08075e0D56FEac6";

const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
const InstrumentManager = artifacts.require('./instrument/InstrumentManager.sol');
const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const Lending = artifacts.require('./instrument/lending/Lending.sol');
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
let lendingToken;
let instrumentManagerAddress;
let instrumentEscrowAddress;
let lending;
let instrumentManager;
let instrumentEscrow;

contract('Lending', ([owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) => {
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

    console.log('Deploying lending instrument.');
    lending = await Lending.new({from: fsp});
    let lendingInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);
    // Activate Lending Instrument
    await instrumentRegistry.activateInstrument(lending.address, lendingInstrumentParameters, {from: fsp});
    instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(1, {from: fsp});
    console.log('Lending instrument manager address: ' + instrumentManagerAddress);
    instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Lending instrument escrow address: ' + instrumentEscrowAddress);
    instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);

    // Deploy ERC20 tokens
    lendingToken = await TokenMock.new();
    collateralToken = await TokenMock.new();
    console.log("Lending token address:" + lendingToken.address);
    console.log("Collateral token address:" + collateralToken.address);
    await priceOracle.setRate(lendingToken.address, collateralToken.address, 1, 100);
    await priceOracle.setRate(collateralToken.address, lendingToken.address, 100, 1);
    console.log("maker1: " + maker1);
    console.log("taker1: " + taker1);
  }),
  it('integration tests', async () => {
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
  })
});
