const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const assert = require('assert');
const SolidityEvent = require("web3");
const LogParser = require(__dirname + "/LogParser.js");
const protobuf = require(__dirname + "/../protobuf-js-messages");
const LineItems = require(__dirname + "/LineItems.js");
const custodianAddress = "0xDbE7A2544eeFfec81A7D898Ac08075e0D56FEac6";


const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
const InstrumentManager = artifacts.require('./instrument/InstrumentManager.sol');
const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const SpotSwap = artifacts.require('./instrument/swap/SpotSwap.sol');
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
let swap;
let instrumentManagerAddress;
let instrumentManager;
let instrumentEscrowAddress;
let instrumentEscrow;
let inputToken;
let outputToken;

contract('SpotSwap', ([owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) => {
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
    swap = await SpotSwap.new({from: fsp});
    let swapInstrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    // Activate Spot Swap Instrument
    await instrumentRegistry.activateInstrument(swap.address, swapInstrumentParameters, {from: fsp});
    instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(1, {from: fsp});
    console.log('Spot swap instrument manager address: ' + instrumentManagerAddress);
    instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Spot swap instrument escrow address: ' + instrumentEscrowAddress);
    instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);

    // Deploy ERC20 tokens
    inputToken = await TokenMock.new();
    outputToken = await TokenMock.new();
    console.log("inputToken address: " + inputToken.address);
    console.log("outputToken address: " + outputToken.address);
    console.log("maker1: " + maker1);
    console.log("taker1: " + taker1);
  }),
  it('integration tests', async () => {
    /**************************** SpotSwap Issuance 1 *****************************************/
    console.log('Creating SpotSwap Issuance 1...');
    // Deposit input tokens to SpotSwap Instrument Escrow
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});

    // Create spot swap issuance.
    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address,
        outputToken.address, 2000000, 40000, 20);
    await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    // Deposit output tokens to SpotSwap Instrument Escrow
    await outputToken.transfer(taker1, 40000);
    await outputToken.approve(instrumentEscrowAddress, 40000, {from: taker1});
    await instrumentEscrow.depositToken(outputToken.address, 40000, {from: taker1});

    // Engage spot swap issuance
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});

    /**************************** SpotSwap Issuance 2 *****************************************/
    console.log('Creating SpotSwap Issuance 2...');
    // Deposit input tokens to SpotSwap Instrument Escrow
    await inputToken.transfer(maker2, 43200000);
    await inputToken.approve(instrumentEscrowAddress, 43200000, {from: maker2});
    await instrumentEscrow.depositToken(inputToken.address, 43200000, {from: maker2});

    // Create spot swap issuance.
    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address,
        outputToken.address, 43200000, 3456, 20);
    await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker2});

    // Deposit output tokens to SpotSwap Instrument Escrow
    await outputToken.transfer(taker2, 3456);
    await outputToken.approve(instrumentEscrowAddress, 3456, {from: taker2});
    await instrumentEscrow.depositToken(outputToken.address, 3456, {from: taker2});

    // Engage spot swap issuance
    await instrumentManager.engageIssuance(2, '0x0', {from: taker2});
  })
});
