const InstrumentEscrow = artifacts.require('../contracts/escrow/InstrumentEscrow.sol');
const Token = artifacts.require('../contracts/lib/token/ERC20Mintable.sol');
const assert = require('assert');

let escrowInstance;
let tokenInstance;
const DIFF = 100000000000000000;       // The transaction cost should be less then 0.1 Ether

contract('InstrumentEscrow', ([owner, account1, account2]) => {
    beforeEach(async () => {
        tokenInstance = await Token.new();
        escrowInstance = await InstrumentEscrow.new();
    }),
    it('should deposit and withdraw Ethers', async () => {
        let prev = parseInt(await web3.eth.getBalance(account2));
        let amount = 10000000000000000000;  // 10 ETH
        await escrowInstance.deposit({from: account2, value: amount});
        let current = parseInt(await web3.eth.getBalance(account2));
        // Verify wallet balance after deposit
        assert.ok(prev - amount - current > 0 && prev - amount - current < DIFF, "The Ether is not transfered");

        // Verify escrow balance
        let balance = web3.utils.fromWei(await escrowInstance.getBalance(account2), "Ether");
        assert.equal(balance, 10);

        await escrowInstance.withdraw(new web3.utils.BN('10000000000000000000'), {from: account2});
        balance = web3.utils.fromWei(await escrowInstance.getBalance(account2), "Ether");
        assert.equal(balance, 0);
    }),
    it('should deposit and withdraw ERC20 tokens', async () => {
        await tokenInstance.mint(account1, 200, {from: owner});
        await tokenInstance.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(tokenInstance.address, 80, {from: account1});
        let balance = (await escrowInstance.getTokenBalance(account1, tokenInstance.address)).toNumber();
        assert.equal(balance, 80);

        let accountBalance = (await tokenInstance.balanceOf(account1)).toNumber();
        let escrowBalance = (await tokenInstance.balanceOf(escrowInstance.address)).toNumber();
        assert.equal(accountBalance, 120);
        assert.equal(escrowBalance, 80);

        await escrowInstance.withdrawToken(tokenInstance.address, 50, {from: account1});
        balance = (await escrowInstance.getTokenBalance(account1, tokenInstance.address)).toNumber();
        assert.equal(balance, 30);
    }),
    it('should get the list of deposited ERC20 tokens', async () => {
        const token1 = await Token.new();
        await token1.mint(account1, 200, {from: owner});
        await token1.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(token1.address, 80, {from: account1});

        const token2 = await Token.new();
        await token2.mint(account1, 200, {from: owner});
        await token2.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(token2.address, 80, {from: account1});

        const token3 = await Token.new();
        await token3.mint(account1, 200, {from: owner});
        await token3.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(token3.address, 80, {from: account1});

        let tokenList = await escrowInstance.getTokenList(account1);
        assert.equal(tokenList.length, 3);
        assert.deepEqual(tokenList, [token1.address, token2.address, token3.address]);

        await escrowInstance.withdrawToken(token2.address, 30, {from: account1});
        tokenList = await escrowInstance.getTokenList(account1);
        assert.equal(tokenList.length, 3);
        assert.deepEqual(tokenList, [token1.address, token2.address, token3.address]);

        await escrowInstance.withdrawToken(token2.address, 50, {from: account1});
        tokenList = await escrowInstance.getTokenList(account1);
        assert.equal(tokenList.length, 2);
        assert.deepEqual(tokenList, [token1.address, token3.address]);
    }),
    it('should not return ETH in token list', async () => {
        const token1 = await Token.new();
        await token1.mint(account1, 200, {from: owner});
        await token1.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(token1.address, 80, {from: account1});

        const token2 = await Token.new();
        await token2.mint(account1, 200, {from: owner});
        await token2.approve(escrowInstance.address, 150, {from: account1});
        await escrowInstance.depositToken(token2.address, 80, {from: account1});

        let amount = 10000000000000000000;  // 10 ETH
        await escrowInstance.deposit({from: account1, value: amount});
        let tokenList = await escrowInstance.getTokenList(account1);
        assert.equal(tokenList.length, 2);
        assert.deepEqual(tokenList, [token1.address, token2.address]);
    })
 });