const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const assert = require('assert');
const SolidityEvent = require("web3");
const LogParser = require(__dirname + "/logParser.js");

const InstrumentManagerInterface = artifacts.require('./instruments/InstrumentManagerInterface.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const IssuanceEscrowInterface = artifacts.require('./escrow/IssuanceEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const SpotSwap = artifacts.require('./instruments/swap/SpotSwap.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');
const InstrumentV1ManagerFactory = artifacts.require('./instrument/v1/InstrumentV1ManagerFactory.sol');
const InstrumentV2ManagerFactory = artifacts.require('./instrument/v2/InstrumentV2ManagerFactory.sol');
const InstrumentV3ManagerFactory = artifacts.require('./instrument/v3/InstrumentV3ManagerFactory.sol');
const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const IssuanceEscrow = artifacts.require('./escrow/IssuanceEscrow.sol');
const StorageFactory = artifacts.require('./storage/StorageFactory.sol');

let parametersUtil;
let swap;
let swapInstrumentManagerAddress;
let swapInstrumentManager;
let swapInstrumentEscrowAddress;
let swapInstrumentEscrow;
let inputToken;
let outputToken;

contract('SpotSwap', ([owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) => {
  beforeEach(async () => {
    // Deploy Storage Factory
    let storageFactory = await StorageFactory.new();

    // Deploy Instrument Managers
    let instrumentV1ManagerFactory = await InstrumentV1ManagerFactory.new();
    let instrumentV2ManagerFactory = await InstrumentV2ManagerFactory.new(storageFactory.address);
    let instrumentV3ManagerFactory = await InstrumentV3ManagerFactory.new();

    // Deploy NUTS token
    let nutsToken = await NUTSToken.new();

    // Deploy Price Oracle
    let priceOracle = await PriceOracle.new();

    // Deploy Escrow Factory
    let escrowFactory = await EscrowFactory.new();

    // Deploy Instrument Registry
    let instrumentRegistry = await InstrumentRegistry.new(0, 0, nutsToken.address, priceOracle.address, escrowFactory.address);

    // Registry Instrument Manager Factories
    await instrumentRegistry.setInstrumentManagerFactory('version1', instrumentV1ManagerFactory.address);
    await instrumentRegistry.setInstrumentManagerFactory('version2', instrumentV2ManagerFactory.address);
    await instrumentRegistry.setInstrumentManagerFactory('version3', instrumentV3ManagerFactory.address);

    parametersUtil = await ParametersUtil.new();
    swap = await SpotSwap.new({from: fsp});
    let swapInstrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    // Activate Spot Swap Instrument
    await instrumentRegistry.activateInstrument(swap.address, 'version3', swapInstrumentParameters, {from: fsp});
    swapInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(swap.address, {from: fsp});
    console.log('Spot swap instrument manager address: ' + swapInstrumentManagerAddress);
    swapInstrumentManager = await InstrumentManagerInterface.at(swapInstrumentManagerAddress);
    swapInstrumentEscrowAddress = await swapInstrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Spot swap instrument escrow address: ' + swapInstrumentEscrowAddress);

    // Deploy ERC20 tokens
    inputToken = await TokenMock.new();
    outputToken = await TokenMock.new();
    console.log("inputToken address: " + inputToken.address);
    console.log("outputToken address: " + outputToken.address);
    swapInstrumentEscrow = await InstrumentEscrowInterface.at(swapInstrumentEscrowAddress);
  }),
  it('invalid parameters', async () => {
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters('0x0000000000000000000000000000000000000000', outputToken.address, 2000000, 40000, 20);
    await expectRevert(swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Input token not set');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, '0x0000000000000000000000000000000000000000', 2000000, 40000, 20);
    await expectRevert(swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Output token not set');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 0, 40000, 20);
    await expectRevert(swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Input amount not set');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 0, 20);
    await expectRevert(swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Output amount not set');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 0);
    await expectRevert(swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Invalid duration');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 91);
    await expectRevert(swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Invalid duration');
  }),
  it('valid parameters but insufficient fund', async () => {
    await inputToken.transfer(maker1, 1500000);
    await inputToken.approve(swapInstrumentEscrowAddress, 1500000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 1500000, {from: maker1});

    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    await expectRevert(swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Insufficient input balance');
  }),
  it('valid parameters', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(swapInstrumentEscrowAddress, 2000000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    assert.equal(2000000, await swapInstrumentEscrow.getTokenBalance(maker1, inputToken.address));

    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});
    assert.equal(1, await swapInstrumentManager.getIssuanceState(1););
    assert.equal(0, await swapInstrumentEscrow.getTokenBalance(maker1, inputToken.address));

    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi);

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let receipt = {logs: events};

    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    assert.equal(2000000, await issuanceEscrow.getTokenBalance(maker1, inputToken.address));
    expectEvent(receipt, 'SwapCreated', {
      issuanceId: new BN(1),
      makerAddress: maker1,
      inputTokenAddress: inputToken.address,
      outputTokenAddress: outputToken.address,
      inputAmount: '2000000',
      outputAmount: '40000',
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: swapInstrumentEscrowAddress,
      to: swapInstrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      to: issuanceEscrowAddress,
      from: swapInstrumentManagerAddress,
      value: '2000000'
    });
  }),
  it('engage spot swap', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(swapInstrumentEscrowAddress, 2000000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    await outputToken.transfer(taker1, 40000);
    await outputToken.approve(swapInstrumentEscrowAddress, 40000, {from: taker1});
    await swapInstrumentEscrow.depositToken(outputToken.address, 40000, {from: taker1});
    assert.equal(40000, await swapInstrumentEscrow.getTokenBalance(taker1, outputToken.address));

    // Engage spot swap issuance
    let engageIssuance = await swapInstrumentManager.engageIssuance(1, '0x0', {from: taker1});
    assert.equal(0, await swapInstrumentEscrow.getTokenBalance(taker1, outputToken.address));
    assert.equal(6, await swapInstrumentManager.getIssuanceState(1));
    assert.equal(2000000, await swapInstrumentEscrow.getTokenBalance(taker1, inputToken.address));
    assert.equal(40000, await swapInstrumentEscrow.getTokenBalance(maker1, outputToken.address));

    let engageIssuanceEvents = LogParser.logParser(engageIssuance.receipt.rawLogs, abis);
    let receipt = {logs: engageIssuanceEvents};
    expectEvent(receipt, 'SwapEngaged', {
      issuanceId: new BN(1),
      takerAddress: taker1
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: swapInstrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: swapInstrumentManagerAddress,
      to: swapInstrumentEscrowAddress,
      value: '2000000'
    });

    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: outputToken.address,
      amount: '40000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: outputToken.address,
      amount: '40000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: swapInstrumentManagerAddress,
      value: '40000'
    });
    expectEvent(receipt, 'Transfer', {
      from: swapInstrumentManagerAddress,
      to: swapInstrumentEscrowAddress,
      value: '40000'
    });
  }),
  it('engage spot swap insufficient output balance', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(swapInstrumentEscrowAddress, 2000000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;

    await outputToken.transfer(taker1, 39999);
    await outputToken.approve(swapInstrumentEscrowAddress, 39999, {from: taker1});
    await swapInstrumentEscrow.depositToken(outputToken.address, 39999, {from: taker1});

    // Engage spot swap issuance
    await expectRevert(swapInstrumentManager.engageIssuance(1, '0x0', {from: taker1}), 'Insufficient output balance');
  }),
  it('cancel spot swap not engageable', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(swapInstrumentEscrowAddress, 2000000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;

    await outputToken.transfer(taker1, 40000);
    await outputToken.approve(swapInstrumentEscrowAddress, 40000, {from: taker1});
    await swapInstrumentEscrow.depositToken(outputToken.address, 40000, {from: taker1});

    // Engage spot swap issuance
    await swapInstrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(swapInstrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1}), 'Issuance terminated');
  }),
  it('cancel spot swap not maker', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(swapInstrumentEscrowAddress, 2000000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    await expectRevert(swapInstrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker2}), 'Only maker can cancel issuance');
  }),
  it('cancel spot swap', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(swapInstrumentEscrowAddress, 2000000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    let cancelIssuance = await swapInstrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1});
    assert.equal(4, await swapInstrumentManager.getIssuanceState(1));

    let cancelIssuanceEvents = LogParser.logParser(cancelIssuance.receipt.rawLogs, abis);
    let receipt = {logs: cancelIssuanceEvents};

    assert.equal(2000000, await swapInstrumentEscrow.getTokenBalance(maker1, inputToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, inputToken.address));
    expectEvent(receipt, 'SwapCancelled', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: swapInstrumentManagerAddress,
      to: swapInstrumentEscrowAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: swapInstrumentManagerAddress,
      value: '2000000'
    });
  }),
  it('notify due after due', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(swapInstrumentEscrowAddress, 2000000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);
    await web3.currentProvider.send({jsonrpc: 2.0, method: 'evm_increaseTime', params: [8640000], id: 0}, (err, result) => { console.log(err, result)});
    let notifyDue = await swapInstrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("swap_due"), web3.utils.fromAscii(""), {from: maker1});
    let notifyDueEvents = LogParser.logParser(notifyDue.receipt.rawLogs, abis);
    let receipt = {logs: notifyDueEvents};

    assert.equal(5, await swapInstrumentManager.getIssuanceState(1));
    expectEvent(receipt, 'SwapCompleteNotEngaged', {
      issuanceId: new BN(1)
    });
    assert.equal(2000000, await swapInstrumentEscrow.getTokenBalance(maker1, inputToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, inputToken.address));
  }),
  it('notify due before due', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(swapInstrumentEscrowAddress, 2000000, {from: maker1});
    await swapInstrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await swapInstrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;

    let notifyDue = await swapInstrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("swap_due"), web3.utils.fromAscii(""), {from: maker1});
    assert.equal(1, await swapInstrumentManager.getIssuanceState(1));
  })
});
