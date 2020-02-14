const InstrumentEscrow = artifacts.require('../contracts/escrow/InstrumentEscrow.sol');
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
const Token = artifacts.require('./mock/TokenMock.sol');
const assert = require('assert');
const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

let escrowInstance;
let tokenInstance;
const DIFF = 100000000000000000;       // The transaction cost should be less then 0.1 Ether
const EMPTY_ADDRESS = '0x0000000000000000000000000000000000000000';

contract('InstrumentEscrow', ([owner, account1, account2]) => {
    beforeEach(async () => {
        tokenInstance = await Token.new();
        escrowInstance = await InstrumentEscrow.new();
    }),
    it('invalid admin operations', async() => {
      await expectRevert(escrowInstance.depositByAdmin(account1, {from: account2, value: 100}), "caller is not the owner");
      await expectRevert(escrowInstance.depositByAdmin(EMPTY_ADDRESS, {from: owner, value: 100}), "EscrowBase: Account not set");
      await expectRevert(escrowInstance.depositByAdmin(account1, {from: owner, value: 0}), "EscrowBase: Amount not set");

      await expectRevert(escrowInstance.depositTokenByAdmin(account1, tokenInstance.address, 10, {from: account2}), "caller is not the owner");
      await expectRevert(escrowInstance.depositTokenByAdmin(EMPTY_ADDRESS, tokenInstance.address, 10, {from: owner}), "EscrowBase: Account not set");
      await expectRevert(escrowInstance.depositTokenByAdmin(account1, EMPTY_ADDRESS, 10, {from: owner}), "EscrowBase: Token not set");
      await expectRevert(escrowInstance.depositTokenByAdmin(account1, tokenInstance.address, 0, {from: owner}), "EscrowBase: Amount not set");

      await expectRevert(escrowInstance.withdrawByAdmin(account1, 100, {from: account2}), "caller is not the owner");
      await expectRevert(escrowInstance.withdrawByAdmin(EMPTY_ADDRESS, 100, {from: owner}), "EscrowBase: Account not set");
      await expectRevert(escrowInstance.withdrawByAdmin(account1, 0, {from: owner}), "EscrowBase: Amount not set");
      await expectRevert(escrowInstance.withdrawByAdmin(account1, 100, {from: owner}), "EscrowBase: Insufficient ETH Balance");

      await expectRevert(escrowInstance.withdrawTokenByAdmin(account1, tokenInstance.address, 10, {from: account2}), "caller is not the owner");
      await expectRevert(escrowInstance.withdrawTokenByAdmin(EMPTY_ADDRESS, tokenInstance.address, 10, {from: owner}), "EscrowBase: Account not set");
      await expectRevert(escrowInstance.withdrawTokenByAdmin(account1, EMPTY_ADDRESS, 10, {from: owner}), "EscrowBase: Token not set");
      await expectRevert(escrowInstance.withdrawTokenByAdmin(account1, tokenInstance.address, 0, {from: owner}), "EscrowBase: Amount not set");
      await expectRevert(escrowInstance.withdrawTokenByAdmin(account1, tokenInstance.address, 10, {from: owner}), "EscrowBase: Insufficient Token Balance");
    }),
    it('invalid operations', async() => {
      await expectRevert(escrowInstance.withdraw(new web3.utils.BN('10000000000000000000'), {from: account2}), "InstrumentEscrow: Insufficient balance.");
      await expectRevert(escrowInstance.withdrawToken(tokenInstance.address, 50, {from: account1}), "InstrumentEscrow: Insufficient balance.");
    }),
    it('should deposit and withdraw Ethers', async () => {
        let prev = parseInt(await web3.eth.getBalance(account2));
        let amount = 10000000000000000000;  // 10 ETH
        await escrowInstance.deposit({from: account2, value: amount});
        let current = parseInt(await web3.eth.getBalance(account2));
        // Verify wallet balance after deposit
        assert.ok(prev - amount - current >= 0 && prev - amount - current < DIFF, "The Ether is not transfered");

        // Verify escrow balance
        let balance = web3.utils.fromWei(await escrowInstance.getBalance(account2), "Ether");
        assert.equal(balance, 10);

        await escrowInstance.withdraw(new web3.utils.BN('10000000000000000000'), {from: account2});
        balance = web3.utils.fromWei(await escrowInstance.getBalance(account2), "Ether");
        assert.equal(balance, 0);
    }),
    it('should deposit and withdraw ERC20 tokens', async () => {
        await tokenInstance.transfer(account1, 80);
        await tokenInstance.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(tokenInstance.address, 80, {from: account1});
        let balance = (await escrowInstance.getTokenBalance(account1, tokenInstance.address)).toNumber();
        assert.equal(balance, 80);

        let accountBalance = (await tokenInstance.balanceOf(account1)).toNumber();
        let escrowBalance = (await tokenInstance.balanceOf(escrowInstance.address)).toNumber();
        assert.equal(accountBalance, 0);
        assert.equal(escrowBalance, 80);

        await escrowInstance.withdrawToken(tokenInstance.address, 50, {from: account1});
        balance = (await escrowInstance.getTokenBalance(account1, tokenInstance.address)).toNumber();
        assert.equal(balance, 30);
    }),
    it('should get the list of deposited ERC20 tokens', async () => {
        const token1 = await Token.new();
        await token1.transfer(account1, 200);
        await token1.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(token1.address, 80, {from: account1});

        const token2 = await Token.new();
        await token2.transfer(account1, 200);
        await token2.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(token2.address, 80, {from: account1});

        const token3 = await Token.new();
        await token3.transfer(account1, 200);
        await token3.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(token3.address, 80, {from: account1});

        let tokenList = await escrowInstance.getTokenList(account1);
        assert.equal(tokenList.length, 3);
        assert.deepEqual(tokenList, [token1.address, token2.address, token3.address]);

        await escrowInstance.withdrawToken(token2.address, 30, {from: account1});
        tokenList = await escrowInstance.getTokenList(account1);
        assert.equal(tokenList.length, 3);
        assert.deepEqual(tokenList, [token1.address, token2.address, token3.address]);
    }),
    it('should allow owner to deposit and withdraw ETH', async () => {
        // Step 1: Account 1 deposits ETH to escrow
        let amount = 10000000000000000000;  // 10 ETH
        let account1Prev = parseInt(await web3.eth.getBalance(account1));
        await escrowInstance.deposit({from: account1, value: amount});
        let account1After = parseInt(await web3.eth.getBalance(account1));
        assert.ok(account1Prev - account1After > amount - DIFF && account1Prev - account1After < amount + DIFF, "The Ether is not transfered");
        let account1Balance = web3.utils.fromWei(await escrowInstance.getBalance(account1), "Ether");
        assert.equal(account1Balance, 10);

        // Step 2: Owner withdraws ETH from account 1
        let ownerPrev = parseInt(await web3.eth.getBalance(owner));
        amount = 4000000000000000000;
        await escrowInstance.withdrawByAdmin(account1, amount + '', {from : owner});
        account1Balance = web3.utils.fromWei(await escrowInstance.getBalance(account1), "Ether");
        assert.equal(account1Balance, 6);
        let ownerAfter = parseInt(await web3.eth.getBalance(owner));
        assert.ok(ownerAfter - ownerPrev < amount + DIFF && ownerAfter - ownerPrev > amount - DIFF, "The Ether is not transfered");

        // Step 3: Owner deposits ETH to account 2
        await escrowInstance.depositByAdmin(account2, {from: owner, value: amount});
        let account2Balance = web3.utils.fromWei(await escrowInstance.getBalance(account2), "Ether");
        assert.equal(account2Balance, 4);
        ownerPrev = ownerAfter;
        ownerAfter = parseInt(await web3.eth.getBalance(owner));
        assert.ok(ownerPrev - ownerAfter > amount - DIFF && ownerPrev - ownerAfter < amount + DIFF, "The Ether is not transfered");

        // Step 4: Account 2 withdraws ETH from escrow
        amount = 3000000000000000000;
        let account2Prev = parseInt(await web3.eth.getBalance(account2));
        await escrowInstance.withdraw(amount + '', {from: account2});
        account2Balance = web3.utils.fromWei(await escrowInstance.getBalance(account2), "Ether");
        assert.equal(account2Balance, 1);
        let account2After = parseInt(await web3.eth.getBalance(account2));
        assert.ok(account2After - account2Prev < amount + DIFF && account2After - account2Prev > amount - DIFF, "The Ether is not transfered");
    }),
    it('should allow owner to deposit and withdraw ERC20 token', async () => {
        // Step 1: Account 1 deposits ERC20 token to escrow
        await tokenInstance.transfer(account1, 200);
        await tokenInstance.approve(escrowInstance.address, 150, {from: account1});
        let account1Prev = (await tokenInstance.balanceOf(account1)).toNumber();
        assert.equal(account1Prev, 200);
        await escrowInstance.depositToken(tokenInstance.address, 80, {from: account1});
        let account1Balance = (await escrowInstance.getTokenBalance(account1, tokenInstance.address)).toNumber();
        let account1After = (await tokenInstance.balanceOf(account1)).toNumber();
        assert.equal(account1Balance, 80);
        assert.equal(account1After, 120);

        // Step 2: Owner withdraws ERC20 token from account 1
        let ownerPrev = (await tokenInstance.balanceOf(owner)).toNumber();
        await escrowInstance.withdrawTokenByAdmin(account1, tokenInstance.address, 30, {from: owner});
        let ownerAfter = (await tokenInstance.balanceOf(owner)).toNumber();
        account1Balance = (await escrowInstance.getTokenBalance(account1, tokenInstance.address)).toNumber();
        assert.equal(ownerAfter - ownerPrev, 30);
        assert.equal(account1Balance, 50);

        // Step 3: Owner deposits ERC20 token to account 2
        ownerPrev = ownerAfter;
        await tokenInstance.approve(escrowInstance.address, 10, {from: owner});
        await escrowInstance.depositTokenByAdmin(account2, tokenInstance.address, 10, {from: owner});
        ownerAfter = (await tokenInstance.balanceOf(owner)).toNumber();
        let account2Balance = (await escrowInstance.getTokenBalance(account2, tokenInstance.address)).toNumber();
        assert.equal(ownerPrev - ownerAfter, 10);
        assert.equal(account2Balance, 10);

        // Step 4: Account 2 withdraws ERC20 token from escrow
        let account2Prev = (await tokenInstance.balanceOf(account2)).toNumber();
        await escrowInstance.withdrawToken(tokenInstance.address, 2, {from: account2});
        let account2After = (await tokenInstance.balanceOf(account2)).toNumber();
        account2Balance = (await escrowInstance.getTokenBalance(account2, tokenInstance.address)).toNumber();
        assert.equal(account2After - account2Prev, 2);
        assert.equal(account2Balance, 8);
    })
 });
