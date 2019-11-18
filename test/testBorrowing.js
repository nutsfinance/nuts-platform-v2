const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const assert = require('assert');
const SolidityEvent = require("web3");
const LogParser = require(__dirname + "/logParser.js");
const protobuf = require(__dirname + "/../protobuf-js-messages");
const custodianAddress = "0xDbE7A2544eeFfec81A7D898Ac08075e0D56FEac6";

const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
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
  }),
  it('invalid parameters', async () => {
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters('0x0000000000000000000000000000000000000000',
        borrowingToken.address, 10000, 20000, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Collateral token not set');

    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        '0x0000000000000000000000000000000000000000', 10000, 20000, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Borrowing token not set');

    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 0, 20000, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Borrowing amount not set');

    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 1, 10000);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Invalid tenor days');

    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 91, 10000);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Invalid tenor days');

    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 4999, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Invalid collateral ratio');

    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20001, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Invalid collateral ratio');

    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 9);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Invalid interest rate');

    borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 50001);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Invalid interest rate');
  }),
  it('valid parameters but insufficient fund', async () => {
    await collateralToken.transfer(maker1, 1000000);
    await collateralToken.approve(instrumentEscrowAddress, 1000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 1000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    await expectRevert(instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1}), 'Insufficient collateral balance');
  }),
  it('valid parameters', async () => {
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});
    assert.equal(2000000, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let receipt = {logs: events};

    let issuanceEscrowAddress = events.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("borrowing_data"));
    let properties = protobuf.BorrowingData.BorrowingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let dueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItem = lineItems[0];
    assert.equal(1, lineItems.length);
    assert.equal(1, lineItem.getLineitemtype());
    assert.equal(1, lineItem.getState());
    assert.equal(custodianAddress.toLowerCase(), lineItem.getObligatoraddress().toAddress().toLowerCase());
    assert.equal(maker1.toLowerCase(), lineItem.getClaimoraddress().toAddress().toLowerCase());
    assert.equal(collateralToken.address.toLowerCase(), lineItem.getTokenaddress().toAddress().toLowerCase());
    assert.equal(2000000, lineItem.getAmount().toNumber());
    assert.equal(dueTimestamp, lineItem.getDuetimestamp().toNumber());
    assert.equal(2, properties.getIssuanceproperties().getState());
    assert.equal(0, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(2000000, await issuanceEscrow.getTokenBalance(custodianAddress, collateralToken.address));
    expectEvent(receipt, 'BorrowingCreated', {
      issuanceId: new BN(1),
      makerAddress: maker1,
      collateralTokenAddress: collateralToken.address,
      borrowingTokenAddress: borrowingToken.address,
      borrowingAmount: '10000',
      collateralRatio: '20000',
      collateralTokenAmount: '2000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentEscrowAddress,
      to: instrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      to: issuanceEscrowAddress,
      from: instrumentManagerAddress,
      value: '2000000'
    });
  }),
  it('cancel borrowing', async () => {
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    let cancelIssuance = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1});
    let cancelIssuanceEvents = LogParser.logParser(cancelIssuance.receipt.rawLogs, abis);
    let receipt = {logs: cancelIssuanceEvents};

    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("borrowing_data"));
    let properties = protobuf.BorrowingData.BorrowingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let dueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItem = lineItems[0];
    assert.equal(1, lineItems.length);
    assert.equal(1, lineItem.getLineitemtype());
    assert.equal(2, lineItem.getState());
    assert.equal(custodianAddress.toLowerCase(), lineItem.getObligatoraddress().toAddress().toLowerCase());
    assert.equal(maker1.toLowerCase(), lineItem.getClaimoraddress().toAddress().toLowerCase());
    assert.equal(collateralToken.address.toLowerCase(), lineItem.getTokenaddress().toAddress().toLowerCase());
    assert.equal(2000000, lineItem.getAmount().toNumber());
    assert.equal(dueTimestamp, lineItem.getDuetimestamp().toNumber());
    assert.equal(5, properties.getIssuanceproperties().getState());
    assert.equal(2000000, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, collateralToken.address));
    expectEvent(receipt, 'BorrowingCancelled', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: collateralToken.address,
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
  }),
  it('cancel borrowing not engageable', async () => {
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;

    // Deposit borrowing tokens to Borrowing Instrument Escrow
    await borrowingToken.transfer(taker1, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker1});
    // Engage borrowing issuance
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker1}), 'Cancel issuance not in engageable state');
  }),
  it('cancel borrowing not from maker', async () => {
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    await expectRevert(instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("cancel_issuance"), web3.utils.fromAscii(""), {from: maker2}), 'Only maker can cancel issuance');
  }),
  it('repaid successful', async () => {
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address, borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);


    // Deposit collateral tokens to borrowing Instrument Escrow
    await borrowingToken.transfer(taker1, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker1});
    assert.equal(20000, await instrumentEscrow.getTokenBalance(taker1, borrowingToken.address));

    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    assert.equal(10000, await instrumentEscrow.getTokenBalance(maker1, borrowingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(taker1, borrowingToken.address));

    await borrowingToken.transfer(maker1, 2000);
    await borrowingToken.approve(instrumentEscrowAddress, 2000, {from: maker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 2000, {from: maker1});
    assert.equal(12000, await instrumentEscrow.getTokenBalance(maker1, borrowingToken.address));
    console.log("before depositToIssuance");
    let depositToIssuance = await instrumentManager.depositToIssuance(1, borrowingToken.address, 12000, {from: maker1});
    console.log("after depositToIssuance");
    let depositToIssuanceEvents = LogParser.logParser(depositToIssuance.receipt.rawLogs, abis);
    let receipt = {logs: depositToIssuanceEvents};

    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("borrowing_data"));
    let properties = protobuf.BorrowingData.BorrowingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let dueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    assert.equal(4, lineItems.length);
    assert.equal(7, properties.getIssuanceproperties().getState());

    assert.equal(0, await instrumentEscrow.getTokenBalance(maker1, borrowingToken.address));
    assert.equal(22000, await instrumentEscrow.getTokenBalance(taker1, borrowingToken.address));
    assert.equal(2000000, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(0, await instrumentEscrow.getTokenBalance(taker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(taker1, borrowingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, borrowingToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(taker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, collateralToken.address));
    expectEvent(receipt, 'BorrowingRepaid', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: borrowingToken.address,
      amount: '12000'
    });
    expectEvent(receipt, 'Transfer', {
      from: instrumentEscrowAddress,
      to: instrumentManagerAddress,
      value: '12000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: borrowingToken.address,
      amount: '12000'
    });

    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: issuanceEscrowAddress,
      value: '12000'
    });

    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
    });

    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: instrumentManagerAddress,
      value: '2000000'
    });

    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
    });

    expectEvent(receipt, 'Transfer', {
      from: instrumentManagerAddress,
      to: instrumentEscrowAddress,
      value: '2000000'
    });
  }),
  it('repaid not engaged', async () => {
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address, borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;
    await borrowingToken.transfer(maker1, 2000);
    await borrowingToken.approve(instrumentEscrowAddress, 2000, {from: maker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 2000, {from: maker1});
    await expectRevert(instrumentManager.depositToIssuance(1, borrowingToken.address, 2000, {from: maker1}), "Issuance not in Engaged");
  }),
  it('repaid not maker', async () => {
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address, borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;

    // Deposit collateral tokens to borrowing Instrument Escrow
    await borrowingToken.transfer(taker1, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(instrumentManager.depositToIssuance(1, borrowingToken.address, 20000, {from: maker2}), "Transfer not allowed");
  }),
  it('repaid not borrowing token', async () => {
    await collateralToken.transfer(maker1, 2200000);
    await collateralToken.approve(instrumentEscrowAddress, 2200000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2200000, {from: maker1});
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address, borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;

    // Deposit collateral tokens to borrowing Instrument Escrow
    await borrowingToken.transfer(taker1, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(instrumentManager.depositToIssuance(1, collateralToken.address, 20000, {from: maker1}), "Must repay with borrowing token");
  }),
  it('repaid not full amount', async () => {
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address, borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;

    // Deposit collateral tokens to borrowing Instrument Escrow
    await borrowingToken.transfer(taker1, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await expectRevert(instrumentManager.depositToIssuance(1, borrowingToken.address, 10000, {from: maker1}), "Must repay in full");
  }),
  it('engagement due after due date', async () => {
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let events = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = events.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    await web3.currentProvider.send({jsonrpc: 2.0, method: 'evm_increaseTime', params: [8640000], id: 0}, (err, result) => { console.log(err, result)});
    let notifyEngagementDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("engagement_due"), web3.utils.fromAscii(""), {from: maker1});
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("borrowing_data"));
    let properties = protobuf.BorrowingData.BorrowingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let dueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItem = lineItems[0];
    assert.equal(1, lineItems.length);
    assert.equal(1, lineItem.getLineitemtype());
    assert.equal(2, lineItem.getState());
    assert.equal(custodianAddress.toLowerCase(), lineItem.getObligatoraddress().toAddress().toLowerCase());
    assert.equal(maker1.toLowerCase(), lineItem.getClaimoraddress().toAddress().toLowerCase());
    assert.equal(collateralToken.address.toLowerCase(), lineItem.getTokenaddress().toAddress().toLowerCase());
    assert.equal(2000000, lineItem.getAmount().toNumber());
    assert.equal(dueTimestamp, lineItem.getDuetimestamp().toNumber());
    assert.equal(6, properties.getIssuanceproperties().getState());

    let notifyEngagementDueEvents = LogParser.logParser(notifyEngagementDue.receipt.rawLogs, abis);
    let receipt = {logs: notifyEngagementDueEvents};

    expectEvent(receipt, 'BorrowingCompleteNotEngaged', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
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
    assert.equal(2000000, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, collateralToken.address));
  }),
  it('engagement due after engaged', async () => {
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});

    await borrowingToken.transfer(taker1, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    let notifyEngagementDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("engagement_due"), web3.utils.fromAscii(""), {from: maker1});
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("borrowing_data"));
    let properties = protobuf.BorrowingData.BorrowingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    assert.equal(3, properties.getIssuanceproperties().getState());
  }),
  it('engagement due before due date', async () => {
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let notifyEngagementDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("engagement_due"), web3.utils.fromAscii(""), {from: maker1});
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("borrowing_data"));
    let properties = protobuf.BorrowingData.BorrowingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    assert.equal(2, properties.getIssuanceproperties().getState());
  }),
  it('borrowing due after engaged', async () => {
    let abis = [].concat(Borrowing.abi, TokenMock.abi, IssuanceEscrow.abi);

    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let createdIssuanceEvents = LogParser.logParser(createdIssuance.receipt.rawLogs, abis);
    let issuanceEscrowAddress = createdIssuanceEvents.find((event) => event.event === 'BorrowingCreated').args.escrowAddress;
    let issuanceEscrow = await IssuanceEscrowInterface.at(issuanceEscrowAddress);

    await borrowingToken.transfer(taker1, 20000);
    await borrowingToken.approve(instrumentEscrowAddress, 20000, {from: taker1});
    await instrumentEscrow.depositToken(borrowingToken.address, 20000, {from: taker1});
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});
    await web3.currentProvider.send({jsonrpc: 2.0, method: 'evm_increaseTime', params: [8640000], id: 0}, (err, result) => { console.log(err, result)});
    let notifyborrowingDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("issuance_due"), web3.utils.fromAscii(""), {from: maker1});
    let customData = await instrumentManager.getCustomData(1, web3.utils.fromAscii("borrowing_data"));
    let properties = protobuf.BorrowingData.BorrowingCompleteProperties.deserializeBinary(Uint8Array.from(Buffer.from(customData.substring(2), 'hex')));
    let dueTimestamp = properties.getIssuanceproperties().getEngagementduetimestamp().toNumber();
    let lineItems = properties.getIssuanceproperties().getSupplementallineitemsList();
    let lineItem = lineItems[0];
    assert.equal(1, lineItems.length);
    assert.equal(1, lineItem.getLineitemtype());
    assert.equal(2, lineItem.getState());
    assert.equal(custodianAddress.toLowerCase(), lineItem.getObligatoraddress().toAddress().toLowerCase());
    assert.equal(maker1.toLowerCase(), lineItem.getClaimoraddress().toAddress().toLowerCase());
    assert.equal(borrowingToken.address.toLowerCase(), lineItem.getTokenaddress().toAddress().toLowerCase());
    assert.equal(2000000, lineItem.getAmount().toNumber());
    assert.equal(dueTimestamp, lineItem.getDuetimestamp().toNumber());
    assert.equal(8, properties.getIssuanceproperties().getState());

    let notifyborrowingDueEvents = LogParser.logParser(notifyborrowingDue.receipt.rawLogs, abis);
    let receipt = {logs: notifyborrowingDueEvents};

    assert.equal(2000000, await instrumentEscrow.getTokenBalance(taker1, collateralToken.address));
    assert.equal(0, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(0, await issuanceEscrow.getTokenBalance(taker1, collateralToken.address));
    expectEvent(receipt, 'BorrowingDelinquent', {
      issuanceId: new BN(1)
    });
    expectEvent(receipt, 'BalanceDecreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: taker1,
      token: collateralToken.address,
      amount: '2000000'
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
  })
});