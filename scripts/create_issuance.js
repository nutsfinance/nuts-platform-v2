const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const InstrumentManager = artifacts.require('./instrument/InstrumentManager.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const argv = require('yargs').argv;
const utils = require('./utils');
const abis = [].concat(InstrumentManager.abi);

module.exports = async function(callback) {
  try {
    let accounts = await utils.getAllAccounts(web3);
    let maker1 = accounts[0];
    let parametersUtil = await ParametersUtil.deployed();
    lendingMakerParameters = await utils.getInstrumentParameters(argv, parametersUtil);
    const instrumentManager = await InstrumentManagerInterface.at(argv.instrumentManagerAddress);
    let result = await instrumentManager.createIssuance(lendingMakerParameters, {from: maker1});
    let logs = await utils.logParser(web3, result.receipt.rawLogs, abis);
    let issuanceCreated = logs.filter(p => p['event'] === 'IssuanceCreated')[0].args;
    console.log("issuanceId: " + issuanceCreated.issuanceId);
    console.log("issuanceEscrowAddress: " + issuanceCreated.issuanceEscrowAddress);
    callback();
  } catch (e) {
    callback(e);
  }
}
