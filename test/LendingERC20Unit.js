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
    await priceOracle.setRate(lendingToken.address, collateralToken.address, 100, 1);
    await priceOracle.setRate(collateralToken.address, lendingToken.address, 1, 100);
    console.log("maker1: " + maker1);
    console.log("taker1: " + taker1);
  }),
  it('invalid parameters', async () => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters('0x0000000000000000000000000000000000000000',
        lendingToken.address, 0, 15000, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Collateral token not set');

    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        '0x0000000000000000000000000000000000000000', 20000, 15000, 1, 10000);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Lending token not set');

    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 0, 15000, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Lending amount not set');

    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 1, 10000);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Invalid tenor days');

    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 91, 10000);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Invalid tenor days');

    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 4999, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Invalid collateral ratio');

    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 20001, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Invalid collateral ratio');

    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 20, 9);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Invalid interest rate');

    lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 20, 50001);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Invalid interest rate');
  }),
  it('valid parameters but insufficient fund', async () => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 25000, 15000, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(lendingMakerParameters, {from: maker1}), 'Insufficient principal balance');
  }),
  it('valid parameters', async () => {
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1}));
    assert.equal(20000, await instrumentEscrow.getTokenBalance(maker1, lendingToken.address));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("lending_data"));
    let properties = protobuf.LendingData.LendingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    assert.equal(2, properties.getIssuanceproperties().getState());
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 1,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(1, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(0, await instrumentEscrow.getTokenBalance(maker1, lendingToken.address));

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let receipt = {logs: events};
    let issuanceEscrowAddress = events.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    assert.equal(20000, await issuanceEscrow.getTokenBalance(custodianAddress, lendingToken.address));
    expectEvent(receipt, 'LendingCreated', {
      issuanceId: new BN(1),
      makerAddress: maker1,
      collateralTokenAddress: collateralToken.address,
      lendingTokenAddress: lendingToken.address,
      lendingAmount: '20000',
      collateralRatio: '15000',
    });

    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '1',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: maker1,
      toAddress: custodianAddress,
      tokenAddress: lendingToken.address,
      amount: '20000'
    });

    expectEvent(receipt, 'SupplementalLineItemCreated', {
      issuanceId: '1',
      itemId: '1',
      itemType: '1',
      state: '1',
      obligatorAddress: custodianAddress,
      claimorAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '20000',
      dueTimestamp: engagementDueTimestamp.toString()
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: custodianAddress,
      token: lendingToken.address,
      amount: '20000'
    });

    expectEvent(receipt, 'Transfer', {
      from: instrumentEscrowAddress,
      to: instrumentManagerAddress,
      value: '20000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: issuanceEscrowAddress,
      value: '20000'
    });
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'lending_create_issuance.csv', accountMappings);
  }),
  it('engage lending', async () => {
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    allTransactions.push(await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1}));
    assert.equal(4000000, await instrumentEscrow.getTokenBalance(taker1, collateralToken.address));
    let engageIssuance = await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    allTransactions.push(engageIssuance);
    assert.equal(1000000, await instrumentEscrow.getTokenBalance(taker1, collateralToken.address));
    assert.equal(20000, await instrumentEscrow.getTokenBalance(taker1, lendingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, lendingToken.address));
    assert.equal(3000000, await issuanceEscrow.getTokenBalance(custodianAddress, collateralToken.address));
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("lending_data"));
    let properties = protobuf.LendingData.LendingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 3,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 4
      },
      {
        id: 2,
        lineItemType: 1,
        state: 1,
        obligatorAddress: custodianAddress,
        claimorAddress: taker1,
        tokenAddress: collateralToken.address,
        amount: 3000000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 3,
        lineItemType: 1,
        state: 1,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 4,
        lineItemType: 1,
        state: 1,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 4000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(3, properties.getIssuanceproperties().getState());
    assert.equal(4, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));

    let events = LogParser.logParser(engageIssuance.receipt.rawLogs, abis);
    let receipt = {logs: events};
    expectEvent(receipt, 'LendingEngaged', {
      issuanceId: '1',
      takerAddress: taker1,
      lendingDueTimstamp: issuanceDueTimestamp.toString(),
      collateralTokenAmount: '3000000'
    });

    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '1',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: taker1,
      toAddress: custodianAddress,
      tokenAddress: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: maker1,
      toAddress: taker1,
      tokenAddress: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: lendingToken.address,
      amount: '20000'
    });

    expectEvent(receipt, 'SupplementalLineItemCreated', {
      issuanceId: '1',
      itemId: '2',
      itemType: '1',
      state: '1',
      obligatorAddress: custodianAddress,
      claimorAddress: taker1,
      tokenAddress: collateralToken.address,
      amount: '3000000',
      dueTimestamp: issuanceDueTimestamp.toString()
    });
    expectEvent(receipt, 'SupplementalLineItemCreated', {
      issuanceId: '1',
      itemId: '3',
      itemType: '1',
      state: '1',
      obligatorAddress: taker1,
      claimorAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '20000',
      dueTimestamp: issuanceDueTimestamp.toString()
    });
    expectEvent(receipt, 'SupplementalLineItemCreated', {
      issuanceId: '1',
      itemId: '4',
      itemType: '1',
      state: '1',
      obligatorAddress: taker1,
      claimorAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '4000',
      dueTimestamp: issuanceDueTimestamp.toString()
    });
    expectEvent(receipt, 'SupplementalLineItemUpdated', {
      issuanceId: '1',
      itemId: '1',
      state: '3',
      reinitiatedTo: '4'
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: custodianAddress,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: lendingToken.address,
      amount: '20000'
    });

    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: issuanceEscrowAddress,
      value: '3000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '20000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '20000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentEscrowAddress,
      to: instrumentManagerAddress,
      value: '3000000'
    });
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'lending_engage_issuance.csv', accountMappings);
  }),
  it('operations after issuance terminated', async() => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});
    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1});
    await expectRevert(instrumentManager.engageIssuance(1, [], {from: taker1}), "Issuance terminated");
    await expectRevert(instrumentManager.depositToIssuance(1, maker1, 1, {from: maker1}), "Issuance terminated");
    await expectRevert(instrumentManager.withdrawFromIssuance(1, maker1, 1, {from: maker1}), "Issuance terminated");
    await expectRevert(instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii(""), [], {from: maker1}), "Issuance terminated");
  }),
  it('cancel lending', async () => {
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    let cancelIssuance = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1});
    allTransactions.push(cancelIssuance);
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("lending_data"));
    let properties = protobuf.LendingData.LendingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 2,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(1, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(5, properties.getIssuanceproperties().getState());

    let cancelIssuanceEvents = LogParser.logParser(cancelIssuance.receipt.rawLogs, abis);
    let receipt = {logs: cancelIssuanceEvents};

    assert.equal(20000, await instrumentEscrow.getTokenBalance(maker1, lendingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, lendingToken.address));

    expectEvent(receipt, 'LendingCancelled', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'IssuanceTerminated', {
      issuanceId: '1'
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
      tokenAddress: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '20000'
    });

    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: lendingToken.address,
      amount: '20000'
    });

    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '20000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '20000'
    });
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'lending_cancel.csv', accountMappings);
  }),
  it('cancel lending not engageable', async () => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1}), 'Cancel issuance not in engageable state');
  }),
  it('cancel lending not from maker', async () => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    await expectRevert(instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker2}), 'Only maker can cancel issuance');
  }),
  it('repaid successful', async () => {
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    allTransactions.push(await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1}));
    assert.equal(4000000, await instrumentEscrow.getTokenBalance(taker1, collateralToken.address));

    allTransactions.push(await instrumentManager.engageIssuance(1, '0x0', {from: taker1}));
    assert.equal(1000000, await instrumentEscrow.getTokenBalance(taker1, collateralToken.address));
    assert.equal(20000, await instrumentEscrow.getTokenBalance(taker1, lendingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, lendingToken.address));
    assert.equal(3000000, await issuanceEscrow.getTokenBalance(custodianAddress, collateralToken.address));

    await lendingToken.transfer(taker1, 24000);
    await lendingToken.approve(instrumentEscrowAddress, 24000, {from: taker1});
    allTransactions.push(await instrumentEscrow.depositToken(lendingToken.address, 24000, {from: taker1}));
    assert.equal(44000, await instrumentEscrow.getTokenBalance(taker1, lendingToken.address));

    let depositToIssuance = await instrumentManager.depositToIssuance(1, lendingToken.address, 24000, {from: taker1});
    allTransactions.push(depositToIssuance);
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("lending_data"));
    let properties = protobuf.LendingData.LendingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 3,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 4
      },
      {
        id: 2,
        lineItemType: 1,
        state: 2,
        obligatorAddress: custodianAddress,
        claimorAddress: taker1,
        tokenAddress: collateralToken.address,
        amount: 3000000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 3,
        lineItemType: 1,
        state: 2,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 4,
        lineItemType: 1,
        state: 2,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 4000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(4, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(7, properties.getIssuanceproperties().getState());

    assert.equal(20000, await instrumentEscrow.getTokenBalance(taker1, lendingToken.address));
    assert.equal(24000, await instrumentEscrow.getTokenBalance(maker1, lendingToken.address));
    assert.equal(4000000, await instrumentEscrow.getTokenBalance(taker1, collateralToken.address));
    assert.equal(0, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(taker1, lendingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, lendingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(taker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, collateralToken.address));

    let depositToIssuanceEvents = LogParser.logParser(depositToIssuance.receipt.rawLogs, abis);
    let receipt = {logs: depositToIssuanceEvents};
    expectEvent(receipt, 'LendingRepaid', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'IssuanceTerminated', {
      issuanceId: '1'
    });

    expectEvent(receipt, 'SupplementalLineItemUpdated', {
      issuanceId: '1',
      itemId: '2',
      state: '2',
      reinitiatedTo: '0'
    });
    expectEvent(receipt, 'SupplementalLineItemUpdated', {
      issuanceId: '1',
      itemId: '3',
      state: '2',
      reinitiatedTo: '0'
    });
    expectEvent(receipt, 'SupplementalLineItemUpdated', {
      issuanceId: '1',
      itemId: '3',
      state: '2',
      reinitiatedTo: '0'
    });

    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '1',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: lendingToken.address,
      amount: '24000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: taker1,
      tokenAddress: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: taker1,
      toAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '24000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '24000'
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: lendingToken.address,
      amount: '24000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: lendingToken.address,
      amount: '24000'
    });

    expectEvent(receipt, 'Transfer', {
      from: instrumentEscrowAddress,
      to: instrumentManagerAddress,
      value: '24000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: issuanceEscrowAddress,
      value: '24000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '24000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '24000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '3000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '3000000'
    });
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'lending_repaid_successful.csv', accountMappings);
  }),
  it('repaid not engaged', async () => {
    await lendingToken.transfer(maker1, 40000);
    await lendingToken.approve(instrumentEscrowAddress, 40000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 40000, {from: maker1});
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    await expectRevert(instrumentManager.depositToIssuance(1, lendingToken.address, 20000, {from: maker1}), "Issuance not in Engaged");
  }),
  it('repaid not taker', async () => {
    await lendingToken.transfer(maker1, 40000);
    await lendingToken.approve(instrumentEscrowAddress, 40000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 40000, {from: maker1});
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: taker2});
    await expectRevert(instrumentManager.depositToIssuance(1, lendingToken.address, 20000, {from: maker1}), "Only taker can repay");
  }),
  it('repaid not lending token', async () => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(instrumentManager.depositToIssuance(1, collateralToken.address, 20000, {from: taker1}), "Must repay with lending token");
  }),
  it('repaid not full amount', async () => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentManager.abi);

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address, lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;

    // Deposit collateral tokens to Lending Instrument Escrow
    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(instrumentManager.depositToIssuance(1, lendingToken.address, 20000, {from: taker1}), "Must repay in full");
  }),
  it('engagement due after due date', async () => {
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);

    let issuanceEscrowAddress = events.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);
    await web3.currentProvider.send({jsonrpc: 2.0, method: 'evm_increaseTime', params: [8640000], id: 1}, (err, result) => { console.log(err, result)});
    let notifyEngagementDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("engagement_due"), web3.utils.fromAscii(""), {from: maker1});
    allTransactions.push(notifyEngagementDue);
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("lending_data"));
    let properties = protobuf.LendingData.LendingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 2,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(1, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(6, properties.getIssuanceproperties().getState());

    let notifyEngagementDueEvents = LogParser.logParser(notifyEngagementDue.receipt.rawLogs, abis);
    let receipt = {logs: notifyEngagementDueEvents};

    expectEvent(receipt, 'LendingCompleteNotEngaged', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'IssuanceTerminated', {
      issuanceId: '1'
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
      tokenAddress: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: lendingToken.address,
      amount: '20000'
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: lendingToken.address,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: lendingToken.address,
      amount: '20000'
    });

    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '20000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '20000'
    });
    assert.equal(20000, await instrumentEscrow.getTokenBalance(maker1, lendingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, lendingToken.address));
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'lending_engagement_due.csv', accountMappings);
  }),
  it('engagement due after engaged', async () => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    let notifyEngagementDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("engagement_due"), web3.utils.fromAscii(""), {from: maker1});
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("lending_data"));
    let properties = protobuf.LendingData.LendingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    assert.equal(3, properties.getIssuanceproperties().getState());
  }),
  it('engagement due before due date', async () => {
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1});

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    let notifyEngagementDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("engagement_due"), web3.utils.fromAscii(""), {from: maker1});
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("lending_data"));
    let properties = protobuf.LendingData.LendingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    assert.equal(2, properties.getIssuanceproperties().getState());
  }),
  it('lending due after engaged', async () => {
    let abis = [].concat(Lending.abi, TokenMock.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    await lendingToken.transfer(maker1, 20000);
    await lendingToken.approve(instrumentEscrowAddress, 20000, {from: maker1});
    allTransactions.push(await instrumentEscrow.depositToken(lendingToken.address, 20000, {from: maker1}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(collateralToken.address,
        lendingToken.address, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    await collateralToken.transfer(taker1, 4000000);
    await collateralToken.approve(instrumentEscrowAddress, 4000000, {from: taker1});
    allTransactions.push(await instrumentEscrow.depositToken(collateralToken.address, 4000000, {from: taker1}));
    allTransactions.push(await instrumentManager.engageIssuance(1, '0x0', {from: taker1}));

    await web3.currentProvider.send({jsonrpc: 2.0, method: 'evm_increaseTime', params: [8640000], id: 1}, (err, result) => { console.log(err, result)});
    let notifyLendingDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("issuance_due"), web3.utils.fromAscii(""), {from: maker1});
    allTransactions.push(notifyLendingDue);
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("lending_data"));
    let properties = protobuf.LendingData.LendingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let engagementDueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let issuanceDueTimestamp = properties.getIssuanceproperties().getIssuanceduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItemsJson = [
      {
        id: 1,
        lineItemType: 1,
        state: 3,
        obligatorAddress: custodianAddress,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 4
      },
      {
        id: 2,
        lineItemType: 1,
        state: 2,
        obligatorAddress: custodianAddress,
        claimorAddress: taker1,
        tokenAddress: collateralToken.address,
        amount: 3000000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 3,
        lineItemType: 1,
        state: 1,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 20000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 4,
        lineItemType: 1,
        state: 1,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: lendingToken.address,
        amount: 4000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(4, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(8, properties.getIssuanceproperties().getState());

    let notifyLendingDueEvents = LogParser.logParser(notifyLendingDue.receipt.rawLogs, abis);
    let receipt = {logs: notifyLendingDueEvents};

    assert.equal(3000000, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(1000000, await instrumentEscrow.getTokenBalance(taker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(taker1, collateralToken.address));
    expectEvent(receipt, 'LendingDelinquent', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'IssuanceTerminated', {
      issuanceId: '1'
    });

    expectEvent(receipt, 'SupplementalLineItemUpdated', {
      issuanceId: '1',
      itemId: '2',
      state: '2',
      reinitiatedTo: '0'
    });

    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: taker1,
      tokenAddress: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: taker1,
      toAddress: maker1,
      tokenAddress: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: collateralToken.address,
      amount: '3000000'
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '3000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: collateralToken.address,
      amount: '3000000'
    });

    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '3000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '3000000'
    });
    let allLogs = [];
    allTransactions.forEach(t => allLogs = allLogs.concat(t.receipt.rawLogs));
    let allEvents = await LogParser.logParserWithTimestamp(allLogs, abis);
    let accountMappings = {};
    accountMappings[maker1] = "maker";
    accountMappings[taker1] = "taker";
    accountMappings[custodianAddress] = "custodian";
    await LogParser.generateCSV(allEvents, '1', 'lending_due.csv', accountMappings);
  })
});
