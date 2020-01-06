const ERC20 = artifacts.require('../lib/token/ERC20.sol');
const argv = require('yargs').argv;
const utils = require('./utils');

module.exports = async function(callback) {
  try {
    let accounts = await utils.getAllAccounts(web3);
    let maker1 = accounts[0];
    let token = await ERC20.at(argv.tokenAddress);
    await token.transfer(maker1, argv.amount);
    callback();
  } catch (e) {
    callback(e);
  }
}
