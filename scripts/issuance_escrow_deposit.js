const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const IssuanceEscrowInterface = artifacts.require('./escrow/IssuanceEscrowInterface.sol');
const argv = require('yargs').argv;
const utils = require('./utils');

module.exports = async function(callback) {
  try {
    let accounts = await utils.getAllAccounts(web3);
    let maker1 = accounts[0];
    let instrumentManager = await InstrumentManagerInterface.at(argv.instrumentManagerAddress);
    let depositToIssuance = await instrumentManager.depositToIssuance(argv.issuanceId, argv.tokenAddress, argv.amount, {from: maker1});
    let issuanceEscrow = await IssuanceEscrowInterface.at(argv.issuanceEscrowAddress);
    console.log("Current balance: " + await issuanceEscrow.getTokenBalance(maker1, argv.tokenAddress));
    callback();
  } catch (e) {
    callback(e);
  }
}
