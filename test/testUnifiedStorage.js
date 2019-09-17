const UnifiedStorage = artifacts.require('../contracts/storage/UnifiedStorage.sol');
const assert = require('assert');
// Import all required modules from openzeppelin-test-helpers
const { BN, constants, expectEvent, expectRevert } = require('openzeppelin-test-helpers');

// Import preferred chai flavor: both expect and should are supported
const { expect } = require('chai');

let unifiedStorage;
contract('UnifiedStorage', ([owner, account1, account2]) => {
    beforeEach(async() => {
        unifiedStorage = await UnifiedStorage.new();
    }),
    it('should allow writer to write string', async() => {
        assert.equal(await unifiedStorage.getString('stringKey'), '', {from: owner});
        assert.equal(await unifiedStorage.getString('stringKey'), '', {from: account2});
        await expectRevert(unifiedStorage.setString('stringKey', 'stringValue', {from: owner}), "WriterRole: Caller does not have the Writer role");
        await expectRevert(unifiedStorage.setString('stringKey', 'stringValue', {from: account1}), "WriterRole: Caller does not have the Writer role");
        await unifiedStorage.addWriter(account1);
        await unifiedStorage.setString('stringKey', 'stringValue', {from: account1});
        assert.equal(await unifiedStorage.getString('stringKey'), 'stringValue', {from: owner});
        assert.equal(await unifiedStorage.getString('stringKey'), 'stringValue', {from: account1});
    }),
    it('should allow writer to write unsigned integer', async() => {
        assert.equal(await unifiedStorage.getUint('uintKey'), 0, {from: owner});
        assert.equal(await unifiedStorage.getUint('uintKey'), 0, {from: account2});
        await expectRevert(unifiedStorage.setUint('uintKey', 100, {from: owner}), "WriterRole: Caller does not have the Writer role");
        await expectRevert(unifiedStorage.setUint('uintKey', 100, {from: account1}), "WriterRole: Caller does not have the Writer role");
        await unifiedStorage.addWriter(account1);
        await unifiedStorage.setUint('uintKey', 100, {from: account1});
        assert.equal(await unifiedStorage.getUint('uintKey'), 100, {from: owner});
        assert.equal(await unifiedStorage.getUint('uintKey'), 100, {from: account1});
    }),
    it('should allow writer to write integer', async() => {
        assert.equal(await unifiedStorage.getInt('intKey'), 0, {from: owner});
        assert.equal(await unifiedStorage.getInt('intKey'), 0, {from: account2});
        await expectRevert(unifiedStorage.setInt('intKey', 100, {from: owner}), "WriterRole: Caller does not have the Writer role");
        await expectRevert(unifiedStorage.setInt('intKey', 100, {from: account1}), "WriterRole: Caller does not have the Writer role");
        await unifiedStorage.addWriter(account1);
        await unifiedStorage.setInt('intKey', 100, {from: account1});
        assert.equal(await unifiedStorage.getInt('intKey'), 100, {from: owner});
        assert.equal(await unifiedStorage.getInt('intKey'), 100, {from: account1});
    }),
    it('should allow writer to write bool', async() => {
        assert.equal(await unifiedStorage.getBool('boolKey'), false, {from: owner});
        assert.equal(await unifiedStorage.getBool('boolKey'), false, {from: account2});
        await expectRevert(unifiedStorage.setBool('boolKey', true, {from: owner}), "WriterRole: Caller does not have the Writer role");
        await expectRevert(unifiedStorage.setBool('boolKey', true, {from: account1}), "WriterRole: Caller does not have the Writer role");
        await unifiedStorage.addWriter(account1);
        await unifiedStorage.setBool('boolKey', true, {from: account1});
        assert.equal(await unifiedStorage.getBool('boolKey'), true, {from: owner});
        assert.equal(await unifiedStorage.getBool('boolKey'), true, {from: account1});
    })
    ,
    it('should allow writer to write address', async() => {
        assert.equal(await unifiedStorage.getAddress('addressKey'), '0x0000000000000000000000000000000000000000', {from: owner});
        assert.equal(await unifiedStorage.getAddress('addressKey'), '0x0000000000000000000000000000000000000000', {from: account2});
        await expectRevert(unifiedStorage.setAddress('addressKey', '0x2932516D9564CB799DDA2c16559caD5b8357a0D6', {from: owner}), "WriterRole: Caller does not have the Writer role");
        await expectRevert(unifiedStorage.setAddress('addressKey', '0x2932516D9564CB799DDA2c16559caD5b8357a0D6', {from: account1}), "WriterRole: Caller does not have the Writer role");
        await unifiedStorage.addWriter(account1);
        await unifiedStorage.setAddress('addressKey', '0x2932516D9564CB799DDA2c16559caD5b8357a0D6', {from: account1});
        assert.equal(await unifiedStorage.getAddress('addressKey'), '0x2932516D9564CB799DDA2c16559caD5b8357a0D6', {from: owner});
        assert.equal(await unifiedStorage.getAddress('addressKey'), '0x2932516D9564CB799DDA2c16559caD5b8357a0D6', {from: account1});
    })
})