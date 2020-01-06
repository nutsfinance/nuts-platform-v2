const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const ERC20 = artifacts.require('../lib/token/ERC20.sol');
const argv = require('yargs').argv;
const utils = require('./utils');

module.exports = async function(callback) {
  try {
    let accounts = await utils.getAllAccounts(web3);
    let maker1 = accounts[0];
    let token = await ERC20.at(argv.tokenAddress);
    let instrumentEscrow = await InstrumentEscrowInterface.at(argv.instrumentEscrowAddress);
    await instrumentEscrow.withdrawToken(token.address, argv.amount, {from: maker1});
    console.log("Current balance: " + await instrumentEscrow.getTokenBalance(maker1, token.address));
    callback();
  } catch (e) {
    callback(e);
  }
}
