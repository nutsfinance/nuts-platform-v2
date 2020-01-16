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
    let swapInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);
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
  it('invalid parameters', async () => {
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters('0x0000000000000000000000000000000000000000', outputToken.address, 2000000, 40000, 20);
    await expectRevert(instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Input token not set');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, '0x0000000000000000000000000000000000000000', 2000000, 40000, 20);
    await expectRevert(instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Output token not set');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 0, 40000, 20);
    await expectRevert(instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Input amount not set');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 0, 20);
    await expectRevert(instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Output amount not set');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 0);
    await expectRevert(instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Invalid duration');

    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 91);
    await expectRevert(instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Invalid duration');
  }),
  it('valid parameters but insufficient fund', async () => {
    await inputToken.transfer(maker1, 1500000);
    await inputToken.approve(instrumentEscrowAddress, 1500000, {from: maker1});
    await instrumentEscrow.depositToken(inputToken.address, 1500000, {from: maker1});

    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    await expectRevert(instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1}), 'Insufficient input balance');
  }),
  it('valid parameters', async () => {
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];

    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1}));
    assert.equal(2000000, await instrumentEscrow.getTokenBalance(maker1, inputToken.address));

    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("swap_data"));
    let properties = protobuf.SwapData.SpotSwapCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    assert.equal(2, properties.getIssuanceproperties().getState());
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 1,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: inputToken.address,
        amount: 2000000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(1, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(0, await instrumentEscrow.getTokenBalance(maker1, inputToken.address));
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    assert.equal(2000000, await issuanceEscrow.getTokenBalance(custodianAddress, inputToken.address));
    let receipt = {logs: events};
    expectEvent(receipt, 'SwapCreated', {
      issuanceId: new BN(1),
      makerAddress: maker1,
      inputTokenAddress: inputToken.address,
      outputTokenAddress: outputToken.address,
      inputAmount: '2000000',
      outputAmount: '40000',
    });

    expectEvent(receipt, 'SupplementalLineItemCreated', {
      issuanceId: '1',
      itemId: '1',
      itemType: '1',
      state: '1',
      obligatorAddress: custodianAddress,
      claimorAddress: maker1,
      tokenAddress: inputToken.address,
      amount: '2000000',
      dueTimestamp: engagementDueTimestamp.toString()
    });

    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '1',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: maker1,
      toAddress: custodianAddress,
      tokenAddress: inputToken.address,
      amount: '2000000'
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
    expectEvent(receipt, 'BalanceIncreased', {
      account: custodianAddress,
      token: inputToken.address,
      amount: '2000000'
    });

    expectEvent(receipt, 'Transfer', {
      from: instrumentEscrowAddress,
      to: instrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: issuanceEscrowAddress,
      value: '2000000'
    });
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'spotswap_create_issuance.csv', accountMappings);
  }),
  it('engage spot swap', async () => {
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];

    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1}));
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    await outputToken.transfer(taker1, 40000);
    await outputToken.approve(instrumentEscrowAddress, 40000, {from: taker1});
    allTransactions.push(await instrumentEscrow.depositToken(outputToken.address, 40000, {from: taker1}));
    assert.equal(40000, await instrumentEscrow.getTokenBalance(taker1, outputToken.address));

    // Engage spot swap issuance
    let engageIssuance = await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    allTransactions.push(engageIssuance);
    let engageIssuanceEvents = LogParser.logParser(engageIssuance.receipt.rawLogs, abis);
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("swap_data"));
    let properties = protobuf.SwapData.SpotSwapCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 2,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: inputToken.address,
        amount: 2000000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(1, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(7, properties.getIssuanceproperties().getState());
    assert.equal(0, await instrumentEscrow.getTokenBalance(taker1, outputToken.address));
    assert.equal(2000000, await instrumentEscrow.getTokenBalance(taker1, inputToken.address));
    assert.equal(40000, await instrumentEscrow.getTokenBalance(maker1, outputToken.address));
    let receipt = {logs: engageIssuanceEvents};
    expectEvent(receipt, 'SwapEngaged', {
      issuanceId: new BN(1),
      takerAddress: taker1
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '1',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: outputToken.address,
      amount: '40000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: maker1,
      toAddress: taker1,
      tokenAddress: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: taker1,
      toAddress: maker1,
      tokenAddress: outputToken.address,
      amount: '40000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: outputToken.address,
      amount: '40000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'SupplementalLineItemUpdated', {
      issuanceId: '1',
      itemId: '1',
      state: '2',
      reinitiatedTo: '0'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: outputToken.address,
      amount: '40000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: outputToken.address,
      amount: '40000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: outputToken.address,
      amount: '40000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: outputToken.address,
      amount: '40000'
    });

    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '40000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '40000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentEscrowAddress,
      to: instrumentManagerAddress,
      value: '40000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: issuanceEscrowAddress,
      value: '40000'
    });
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'spotswap_engage_issuance.csv', accountMappings);
  }),
  it('engage spot swap insufficient output balance', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;

    await outputToken.transfer(taker1, 39999);
    await outputToken.approve(instrumentEscrowAddress, 39999, {from: taker1});
    await instrumentEscrow.depositToken(outputToken.address, 39999, {from: taker1});

    // Engage spot swap issuance
    await expectRevert(instrumentManager.engageIssuance(1, '0x0', {from: taker1}), 'Insufficient output balance');
  }),
  it('cancel spot swap not engageable', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;

    await outputToken.transfer(taker1, 40000);
    await outputToken.approve(instrumentEscrowAddress, 40000, {from: taker1});
    await instrumentEscrow.depositToken(outputToken.address, 40000, {from: taker1});

    // Engage spot swap issuance
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1}), 'Issuance terminated');
  }),
  it('cancel spot swap not maker', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    await expectRevert(instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker2}), 'Only maker can cancel issuance');
  }),
  it('cancel spot swap', async () => {
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];

    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1}));
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    let cancelIssuance = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1});
    allTransactions.push(cancelIssuance);
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("swap_data"));
    let properties = protobuf.SwapData.SpotSwapCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 2,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: inputToken.address,
        amount: 2000000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(1, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(5, properties.getIssuanceproperties().getState());

    let cancelIssuanceEvents = LogParser.logParser(cancelIssuance.receipt.rawLogs, abis);
    let receipt = {logs: cancelIssuanceEvents};

    assert.equal(2000000, await instrumentEscrow.getTokenBalance(maker1, inputToken.address));
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
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'SupplementalLineItemUpdated', {
      issuanceId: '1',
      itemId: '1',
      state: '2',
      reinitiatedTo: '0'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: inputToken.address,
      amount: '2000000'
    });
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'spotswap_cancel_issuance.csv', accountMappings);
  }),
  it('notify due after due', async () => {
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];

    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1}));
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);
    await web3.currentProvider.send({jsonrpc: 2.0, method: 'evm_increaseTime', params: [8640000], id: 1}, (err, result) => { console.log(err, result)});
    let notifyDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("issuance_due"), web3.utils.fromAscii(""), {from: maker1});
    allTransactions.push(notifyDue);
    let notifyDueEvents = LogParser.logParser(notifyDue.receipt.rawLogs, abis);

    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("swap_data"));
    let properties = protobuf.SwapData.SpotSwapCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    assert.equal(6, properties.getIssuanceproperties().getState());
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 2,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: inputToken.address,
        amount: 2000000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(1, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));

    let receipt = {logs: notifyDueEvents};
    expectEvent(receipt, 'SwapCompleteNotEngaged', {
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
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'SupplementalLineItemUpdated', {
      issuanceId: '1',
      itemId: '1',
      state: '2',
      reinitiatedTo: '0'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: inputToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: inputToken.address,
      amount: '2000000'
    });
    assert.equal(2000000, await instrumentEscrow.getTokenBalance(maker1, inputToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, inputToken.address));
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'spotswap_engagement_due.csv', accountMappings);
  }),
  it('notify due before due', async () => {
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});
    let abis = [].concat(SpotSwap.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);
    let spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address, outputToken.address, 2000000, 40000, 20);
    let createdIssuance = await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'SwapCreated').args.escrowAddress;

    let notifyDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("issuance_due"), web3.utils.fromAscii(""), {from: maker1});
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("swap_data"));
    let properties = protobuf.SwapData.SpotSwapCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    assert.equal(2, properties.getIssuanceproperties().getState());
  })
});
