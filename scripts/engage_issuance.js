const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const argv = require('yargs').argv;
const utils = require('./utils');

module.exports = async function(callback) {
  try {
    let accounts = await utils.getAllAccounts(web3);
    let taker1 = accounts[0];
    const instrumentManager = await InstrumentManagerInterface.at(argv.instrumentManagerAddress);
    await instrumentManager.engageIssuance(argv.issuanceId, web3.utils.fromAscii(argv.buyerParameters), {from: taker1});
    callback();
  } catch (e) {
    callback(e);
  }
}
