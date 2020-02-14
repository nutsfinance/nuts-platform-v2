const InstrumentBase = artifacts.require('../contracts/instrument/InstrumentBase.sol');
const Token = artifacts.require('./mock/TokenMock.sol');
const assert = require('assert');
const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

let instrumentBase;
const EMPTY_ADDRESS = '0x0000000000000000000000000000000000000000';

contract('InstrumentBase', ([owner, account1, account2, account3, account4, account5]) => {
    beforeEach(async () => {
        instrumentBase = await InstrumentBase.new();
    }),
    it('invalid initialize', async() => {
      await expectRevert(instrumentBase.initialize(0, account1, account2, account3, account4, account5), "Issuance ID not set");
      await expectRevert(instrumentBase.initialize(1, EMPTY_ADDRESS, account2, account3, account4, account5), "FSP not set");
      await expectRevert(instrumentBase.initialize(1, account1, account2, EMPTY_ADDRESS, account4, account5), "Instrument Escrow not set");
      await expectRevert(instrumentBase.initialize(1, account1, account2, account3, EMPTY_ADDRESS, account5), "Issuance Escrow not set");
      await expectRevert(instrumentBase.initialize(1, account1, account2, account3, account4, EMPTY_ADDRESS), "Price Oracle not set");

      await instrumentBase.initialize(1, account1, account2, account3, account4, account5);
      await expectRevert(instrumentBase.initialize(1, account1, account2, account3, account4, account5), "Already initialized");
    })
 });
