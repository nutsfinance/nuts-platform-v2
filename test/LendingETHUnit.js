const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const assert = require('assert');
const SolidityEvent = require("web3");
const LogParser = require(__dirname + "/LogParser.js");
const LineItems = require(__dirname + "/LineItems.js");
const protobuf = require(__dirname + "/../protobuf-js-messages");
const custodianAddress = "0xDbE7A2544eeFfec81A7D898Ac08075e0D56FEac6";
const ethAddress = "0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF";

const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
const InstrumentManager = artifacts.require('./instrument/InstrumentManager.sol');
const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const Lending = artifacts.require('./instrument/lending/Lending.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const IssuanceEscrowInterface = artifacts.require('./escrow/IssuanceEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const NUTSToken = artifacts.require('./token/NUTSToken.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const IssuanceEscrow = artifacts.require('./escrow/IssuanceEscrow.sol');
const InstrumentEscrow = artifacts.require('./escrow/InstrumentEscrow.sol');

let parametersUtil;
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

    console.log("maker1: " + maker1);
    console.log("taker1: " + taker1);
  }),
  it('valid parameters', async () => {
    let abis = [].concat(Lending.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    allTransactions.push(await instrumentEscrow.deposit({from: maker1, value: 20000}));
    assert.equal(20000, await instrumentEscrow.getBalance(maker1));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(ethAddress,
        ethAddress, 20000, 15000, 20, 10000);
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
        tokenAddress: ethAddress,
        amount: 20000,
        dueTimestamp: engagementDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(1, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(0, await instrumentEscrow.getBalance(maker1));

    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let receipt = {logs: events};
    let issuanceEscrowAddress = events.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    assert.equal(20000, await issuanceEscrow.getBalance(custodianAddress));
    expectEvent(receipt, 'LendingCreated', {
      issuanceId: new BN(1),
      makerAddress: maker1,
      collateralTokenAddress: ethAddress,
      lendingTokenAddress: ethAddress,
      lendingAmount: '20000',
      collateralRatio: '15000',
    });

    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '1',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: maker1,
      toAddress: custodianAddress,
      tokenAddress: ethAddress,
      amount: '20000'
    });

    expectEvent(receipt, 'SupplementalLineItemCreated', {
      issuanceId: '1',
      itemId: '1',
      itemType: '1',
      state: '1',
      obligatorAddress: custodianAddress,
      claimorAddress: maker1,
      tokenAddress: ethAddress,
      amount: '20000',
      dueTimestamp: engagementDueTimestamp.toString()
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: custodianAddress,
      token: ethAddress,
      amount: '20000'
    });
  }),
  it('engage lending', async () => {
    let abis = [].concat(Lending.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    allTransactions.push(await instrumentEscrow.deposit({from: maker1, value: 20000}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(ethAddress, ethAddress, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    // Deposit collateral tokens to Lending Instrument Escrow
    allTransactions.push(await instrumentEscrow.deposit({from: taker1, value: 40000}));
    assert.equal(40000, await instrumentEscrow.getBalance(taker1));
    let engageIssuance = await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    allTransactions.push(engageIssuance);
    assert.equal(30000, await instrumentEscrow.getBalance(taker1));
    assert.equal(0, await issuanceEscrow.getBalance(maker1));
    assert.equal(30000, await issuanceEscrow.getBalance(custodianAddress));
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
        tokenAddress: ethAddress,
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
        tokenAddress: ethAddress,
        amount: 30000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 3,
        lineItemType: 1,
        state: 1,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: ethAddress,
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
        tokenAddress: ethAddress,
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
      collateralTokenAmount: '30000'
    });

    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '1',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: taker1,
      toAddress: custodianAddress,
      tokenAddress: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: maker1,
      toAddress: taker1,
      tokenAddress: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: ethAddress,
      amount: '20000'
    });

    expectEvent(receipt, 'SupplementalLineItemCreated', {
      issuanceId: '1',
      itemId: '2',
      itemType: '1',
      state: '1',
      obligatorAddress: custodianAddress,
      claimorAddress: taker1,
      tokenAddress: ethAddress,
      amount: '30000',
      dueTimestamp: issuanceDueTimestamp.toString()
    });
    expectEvent(receipt, 'SupplementalLineItemCreated', {
      issuanceId: '1',
      itemId: '3',
      itemType: '1',
      state: '1',
      obligatorAddress: taker1,
      claimorAddress: maker1,
      tokenAddress: ethAddress,
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
      tokenAddress: ethAddress,
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
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: custodianAddress,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: ethAddress,
      amount: '20000'
    });
  }),
  it('cancel lending', async () => {
    let abis = [].concat(Lending.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    allTransactions.push(await instrumentEscrow.deposit({from: maker1, value: 20000}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(ethAddress, ethAddress, 20000, 15000, 20, 10000);
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
        tokenAddress: ethAddress,
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

    assert.equal(20000, await instrumentEscrow.getBalance(maker1));
    assert.equal(0, await issuanceEscrow.getBalance(maker1));

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
      tokenAddress: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '20000'
    });

    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: ethAddress,
      amount: '20000'
    });
  }),
  it('repaid successful', async () => {
    let abis = [].concat(Lending.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    allTransactions.push(await instrumentEscrow.deposit({from: maker1, value: 20000}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(ethAddress, ethAddress, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    // Deposit collateral tokens to Lending Instrument Escrow
    allTransactions.push(await instrumentEscrow.deposit({from: taker1, value: 40000}));
    assert.equal(40000, await instrumentEscrow.getBalance(taker1));

    allTransactions.push(await instrumentManager.engageIssuance(1, '0x0', {from: taker1}));
    assert.equal(30000, await instrumentEscrow.getBalance(taker1));
    assert.equal(0, await issuanceEscrow.getBalance(maker1));
    assert.equal(30000, await issuanceEscrow.getBalance(custodianAddress));

    allTransactions.push(await instrumentEscrow.deposit({from: taker1, value: 24000}));
    assert.equal(54000, await instrumentEscrow.getBalance(taker1));

    let depositToIssuance = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("repay_full"), web3.utils.fromAscii(""), {from: taker1});
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
        tokenAddress: ethAddress,
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
        tokenAddress: ethAddress,
        amount: 30000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 3,
        lineItemType: 1,
        state: 2,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: ethAddress,
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
        tokenAddress: ethAddress,
        amount: 4000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      }
    ];
    assert.equal(4, lineItems.length);
    lineItemsJson.forEach((json) => assert.ok(LineItems.searchLineItems(lineItems, json).length > 0));
    assert.equal(7, properties.getIssuanceproperties().getState());

    assert.equal(60000, await instrumentEscrow.getBalance(taker1));
    assert.equal(24000, await instrumentEscrow.getBalance(maker1));
    assert.equal(0, await issuanceEscrow.getBalance(taker1));
    assert.equal(0, await issuanceEscrow.getBalance(maker1));

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
      tokenAddress: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '1',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: ethAddress,
      amount: '4000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: taker1,
      tokenAddress: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: taker1,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: taker1,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '4000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: taker1,
      toAddress: taker1,
      tokenAddress: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '4000'
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: ethAddress,
      amount: '4000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: ethAddress,
      amount: '4000'
    });
  }),
  it('engagement due after due date', async () => {
    let abis = [].concat(Lending.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    allTransactions.push(await instrumentEscrow.deposit({from: maker1, value: 20000}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(ethAddress,
        ethAddress, 20000, 15000, 20, 10000);
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
        tokenAddress: ethAddress,
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
      tokenAddress: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: custodianAddress,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '20000'
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: ethAddress,
      amount: '20000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: ethAddress,
      amount: '20000'
    });
  }),
  it('lending due after engaged', async () => {
    let abis = [].concat(Lending.abi, IssuanceEscrow.abi, InstrumentEscrow.abi, InstrumentManager.abi);
    let allTransactions = [];
    allTransactions.push(await instrumentEscrow.deposit({from: maker1, value: 20000}));

    let lendingMakerParameters = await parametersUtil.getLendingMakerParameters(ethAddress,
        ethAddress, 20000, 15000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    allTransactions.push(createdIssuance);
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'LendingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    allTransactions.push(await instrumentEscrow.deposit({from: taker1, value: 40000}));
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
        tokenAddress: ethAddress,
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
        tokenAddress: ethAddress,
        amount: 30000,
        dueTimestamp: issuanceDueTimestamp,
        reinitiatedTo: 0
      },
      {
        id: 3,
        lineItemType: 1,
        state: 1,
        obligatorAddress: taker1,
        claimorAddress: maker1,
        tokenAddress: ethAddress,
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
        tokenAddress: ethAddress,
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

    assert.equal(30000, await instrumentEscrow.getBalance(maker1));
    assert.equal(30000, await instrumentEscrow.getBalance(taker1));
    assert.equal(0, await issuanceEscrow.getBalance(maker1));
    assert.equal(0, await issuanceEscrow.getBalance(taker1));
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
      tokenAddress: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '3',
      fromAddress: taker1,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'TokenTransferred', {
      issuanceId: '1',
      transferType: '2',
      fromAddress: maker1,
      toAddress: maker1,
      tokenAddress: ethAddress,
      amount: '30000'
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: custodianAddress,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: taker1,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: ethAddress,
      amount: '30000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: ethAddress,
      amount: '30000'
    });
  })
});
