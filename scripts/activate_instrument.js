const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const argv = require('yargs').argv;
const utils = require('./utils');

module.exports = async function(callback) {
  try {
      let accounts = await utils.getAllAccounts(web3);
      let fsp = argv.fsp;
      let instrumentType = argv.instrument;
      let instrumentRegistry = await InstrumentRegistry.at(argv.instrumentRegistryAddress);
      console.log('InstrumentRegistry Address: ' + instrumentRegistry.address);
      let parametersUtil = await ParametersUtil.deployed();
      let instrumentParameters = await parametersUtil.getInstrumentParameters(argv.instrumentTerminationTimestamp, argv.instrumentOverrideTimestamp, fsp, argv.supportMakerWhitelist === 'true', argv.supportTakerWhitelist === 'true');

      // Activate Instrument
      console.log('Deploying instrument.');
      let instrument = await utils.getInstrumentCode(instrumentType, artifacts).new({from: fsp});
      let txn = await instrumentRegistry.activateInstrument(instrument.address, instrumentParameters, {from: fsp});
      let logs = await utils.logParser(web3, txn.receipt.rawLogs, [].concat(InstrumentRegistry.abi));
      let instrumentActivated = logs.filter(p => p['event'] === 'InstrumentActivated')[0].args;
      const instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(instrumentActivated.instrumentId, {from: fsp});
      console.log('Instrument manager address: ' + instrumentManagerAddress);
      const instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
      console.log('Get instrument');
      const instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
      console.log('Instrument escrow address: ' + instrumentEscrowAddress);
      callback();
  } catch (e) {
    callback(e);
  }
}
