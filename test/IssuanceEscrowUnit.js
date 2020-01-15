const IssuanceEscrow = artifacts.require('../contracts/escrow/IssuanceEscrow.sol');
const Token = artifacts.require('./mock/TokenMock.sol');
const assert = require('assert');

let escrowInstance;
let tokenInstance;
const DIFF = 100000000000000000;       // The transaction cost should be less then 0.1 Ether

contract('InstrumentEscrow', ([owner, account1, account2]) => {
    beforeEach(async () => {
        tokenInstance = await Token.new();
        escrowInstance = await IssuanceEscrow.new();
    }),
    it('should transfer Ethers ownership', async () => {
        // Step 1: Deposit 10 ETH for account2
        let amount = 10000000000000000000;  // 10 ETH
        await escrowInstance.depositByAdmin(account2, {from: owner, value: amount});
        let account2Balance = web3.utils.fromWei(await escrowInstance.getBalance(account2), "Ether");
        assert.equal(account2Balance, 10);

        // Step 2: Transfer 3 ETH from account2 to account1
        amount = 3000000000000000000;
        let account1Balance = web3.utils.fromWei(await escrowInstance.getBalance(account1), "Ether");
        assert.equal(account1Balance, 0);
        await escrowInstance.transfer(account2, account1, amount + '', {from: owner});
        account1Balance = web3.utils.fromWei(await escrowInstance.getBalance(account1), "Ether");
        account2Balance = web3.utils.fromWei(await escrowInstance.getBalance(account2), "Ether");
        assert.equal(account1Balance, 3);
        assert.equal(account2Balance, 7);
    }),
    it('should transfer ERC20 token ownership', async () => {
        // Step 1: Deposit 120 tokens for account2
        await tokenInstance.approve(escrowInstance.address, 120, {from: owner});
        await escrowInstance.depositTokenByAdmin(account2, tokenInstance.address, 120, {from: owner});
        let account2Balance = (await escrowInstance.getTokenBalance(account2, tokenInstance.address)).toNumber();
        assert.equal(account2Balance, 120);

        // Step 2: Transfer 80 tokens from account2 to account1
        let account1Balance = (await escrowInstance.getTokenBalance(account1, tokenInstance.address)).toNumber();
        assert.equal(account1Balance, 0);
        await escrowInstance.transferToken(account2, account1, tokenInstance.address, 80, {from: owner});
        account1Balance = (await escrowInstance.getTokenBalance(account1, tokenInstance.address)).toNumber();
        account2Balance = (await escrowInstance.getTokenBalance(account2, tokenInstance.address)).toNumber();
        assert.equal(account1Balance, 80);
        assert.equal(account2Balance, 40);
    })
 });
