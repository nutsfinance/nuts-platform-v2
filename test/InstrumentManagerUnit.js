const InstrumentManager = artifacts.require('../contracts/instrument/InstrumentManager.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const NUTSTokenMock = artifacts.require('./mock/NUTSTokenMock.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const Token = artifacts.require('./mock/TokenMock.sol');
const assert = require('assert');
const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const EMPTY_ADDRESS = '0x0000000000000000000000000000000000000000';
let instrumentManager;
contract('InstrumentManager', ([owner, account1, account2, account3, account4, account5]) => {
    beforeEach(async () => {
      let instrumentManagerFactory = await InstrumentManagerFactory.new();
      let nutsToken = await NUTSTokenMock.new();
      let priceOracle = await PriceOracle.new();
      let escrowFactory = await EscrowFactory.new();
      let instrumentRegistry = await InstrumentRegistry.new(instrumentManagerFactory.address,
          0, 0, nutsToken.address, priceOracle.address, escrowFactory.address);
      let parametersUtil = await ParametersUtil.new();
      let borrowingInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, 1, owner, true, true);
      instrumentManager = await InstrumentManager.new(1, account1, account2, instrumentRegistry.address, borrowingInstrumentParameters);
      await instrumentManager.setMakerWhitelist(account2, true, {from: account1});
      await instrumentManager.setTakerWhitelist(account3, true, {from: account1});
    }),
    it('invalid constructor', async() => {
      let parametersUtil = await ParametersUtil.new();
      let borrowingInstrumentParameters = await parametersUtil.getInstrumentParameters(0, 0, owner, false, false);

      await expectRevert(InstrumentManager.new(1, EMPTY_ADDRESS, account2, account3, borrowingInstrumentParameters), "FSP not set");
      await expectRevert(InstrumentManager.new(1, account1, EMPTY_ADDRESS, account3, borrowingInstrumentParameters), "Instrument not set");
      await expectRevert(InstrumentManager.new(1, account1, account2, EMPTY_ADDRESS, borrowingInstrumentParameters), "Instrument config not set");
      await expectRevert(InstrumentManager.new(1, account1, account2, account3, []), "Instrument parameters not set");
      await expectRevert(InstrumentManager.new(1, account1, account2, account3, borrowingInstrumentParameters), "Termination not set");
    }),
    it('deactivated', async() => {
      await instrumentManager.deactivate({from: account1});
      await expectRevert(instrumentManager.deactivate({from: account1}), "Instrument deactivated");
      await expectRevert(instrumentManager.createIssuance([], {from: account2}), "Instrument deactivated");
    }),
    it('issuance operations invalid arguments', async() => {
      await expectRevert(instrumentManager.engageIssuance(1, [], {from: account3}), "Issuance not exist");
      await expectRevert(instrumentManager.depositToIssuance(1, account1, 0, {from: account3}), "Amount not set");
      await expectRevert(instrumentManager.depositToIssuance(1, account1, 20, {from: account3}), "Issuance not exist");
      await expectRevert(instrumentManager.withdrawFromIssuance(1, account1, 0, {from: account3}), "Amount not set");
      await expectRevert(instrumentManager.withdrawFromIssuance(1, account1, 20, {from: account3}), "Issuance not exist");
      await expectRevert(instrumentManager.notifyCustomEvent(1, web3.utils.fromAscii(""), [], {from: account3}), "Issuance not exist");

    }),
    it('permissions set whitelist', async() => {
      await expectRevert(instrumentManager.deactivate({from: account2}), "Cannot deactivate");
      await instrumentManager.setMakerWhitelist(account2, true, {from: account1});
      await expectRevert(instrumentManager.setMakerWhitelist(account1, true, {from: account2}), "Only FSP can whitelist");
      await instrumentManager.setTakerWhitelist(account2, true, {from: account1});
      await expectRevert(instrumentManager.setTakerWhitelist(account1, true, {from: account2}), "Only FSP can whitelist");
    }),
    it('permissions use whitelist', async() => {
      await expectRevert(instrumentManager.createIssuance([], {from: account3}), "Maker not allowed");
      await expectRevert(instrumentManager.engageIssuance(1, [], {from: account2}), "Taker not allowed");
    })
 });
