const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const assert = require('assert');
const SolidityEvent = require("web3");
const LogParser = require(__dirname + "/logParser.js");

const InstrumentManagerInterface = artifacts.require('./instruments/InstrumentManagerInterface.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const IssuanceEscrowInterface = artifacts.require('./escrow/IssuanceEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const Borrowing = artifacts.require('./instruments/borrowing/Borrowing.sol');
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
let instrumentManager;
let collateralToken;
let borrowingToken;
let instrumentEscrow;
let instrumentEscrowAddress;
let borrowingInstrumentManagerAddress;
let borrowingInstrumentEscrowAddress;
let borrowing;



contract('Borrowing', ([owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) => {
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

    console.log('Deploying borrowing instrument.');
    borrowing = await Borrowing.new({from: fsp});
    let borrowingInstrumentParameters = await parametersUtil.getInstrumentParameters(0, fsp, false, false);
    // Activate Borrowing Instrument
    await instrumentRegistry.activateInstrument(borrowing.address, 'version3', borrowingInstrumentParameters, {from: fsp});
    borrowingInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(borrowing.address, {from: fsp});
    console.log('Borrowing instrument manager address: ' + borrowingInstrumentManagerAddress);
    borrowingInstrumentManager = await InstrumentManagerInterface.at(borrowingInstrumentManagerAddress);
    borrowingInstrumentEscrowAddress = await borrowingInstrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Borrowing instrument escrow address: ' + borrowingInstrumentEscrowAddress);

    // Deploy ERC20 tokens
    borrowingToken = await TokenMock.new();
    collateralToken = await TokenMock.new();
    await priceOracle.setRate(borrowingToken.address, collateralToken.address, 1, 100);
    await priceOracle.setRate(collateralToken.address, borrowingToken.address, 100, 1);

    let instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(borrowing.address, {from: fsp});
    console.log('Instrument manager address: ' + instrumentManagerAddress);
    instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Instrument escrow address: ' + instrumentEscrowAddress);
    instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);
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

    assert.equal(0, await instrumentEscrow.getTokenBalance(maker1, collateralToken.address));
    assert.equal(1, await instrumentManager.getIssuanceState(1));
    assert.equal(2000000, await issuanceEscrow.getTokenBalance(maker1, collateralToken.address));
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
      from: borrowingInstrumentEscrowAddress,
      to: borrowingInstrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      to: issuanceEscrowAddress,
      from: borrowingInstrumentManagerAddress,
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

    assert.equal(4, await instrumentManager.getIssuanceState(1));
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
      from: borrowingInstrumentManagerAddress,
      to: borrowingInstrumentEscrowAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: issuanceEscrowAddress,
      to: borrowingInstrumentManagerAddress,
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

    let depositToIssuance = await instrumentManager.depositToIssuance(1, borrowingToken.address, 12000, {from: maker1});
    let depositToIssuanceEvents = LogParser.logParser(depositToIssuance.receipt.rawLogs, abis);
    let receipt = {logs: depositToIssuanceEvents};

    assert.equal(6, await instrumentManager.getIssuanceState(1));
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
      from: borrowingInstrumentEscrowAddress,
      to: borrowingInstrumentManagerAddress,
      value: '12000'
    });
    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: borrowingToken.address,
      amount: '12000'
    });

    expectEvent(receipt, 'Transfer', {
      from: borrowingInstrumentManagerAddress,
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
      to: borrowingInstrumentManagerAddress,
      value: '2000000'
    });

    expectEvent(receipt, 'BalanceIncreased', {
      account: maker1,
      token: collateralToken.address,
      amount: '2000000'
    });

    expectEvent(receipt, 'Transfer', {
      from: borrowingInstrumentManagerAddress,
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
    await expectRevert(instrumentManager.depositToIssuance(1, borrowingToken.address, 2000, {from: maker1}), "Must repay in engaged state");
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
    assert.equal(5, await instrumentManager.getIssuanceState(1));

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
      to: borrowingInstrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: borrowingInstrumentManagerAddress,
      to: borrowingInstrumentEscrowAddress,
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
    assert.equal(2, await instrumentManager.getIssuanceState(1));
  }),
  it('engagement due before due date', async () => {
    await collateralToken.transfer(maker1, 2000000);
    await collateralToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(collateralToken.address, 2000000, {from: maker1});

    let borrowingMakerParameters = await parametersUtil.getBorrowingMakerParameters(collateralToken.address,
        borrowingToken.address, 10000, 20000, 20, 10000);
    let createdIssuance = await instrumentManager.createIssuance(borrowingMakerParameters, {from: maker1});
    let notifyEngagementDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("engagement_due"), web3.utils.fromAscii(""), {from: maker1});
    assert.equal(1, await instrumentManager.getIssuanceState(1));
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
    let notifyborrowingDue = await instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii("borrowing_due"), web3.utils.fromAscii(""), {from: maker1});
    assert.equal(7, await instrumentManager.getIssuanceState(1));

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
      to: borrowingInstrumentManagerAddress,
      value: '2000000'
    });
    expectEvent(receipt, 'Transfer', {
      from: borrowingInstrumentManagerAddress,
      to: borrowingInstrumentEscrowAddress,
      value: '2000000'
    });
  })
});
