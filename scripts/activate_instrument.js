const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const argv = require('yargs').argv;
const utils = require('./utils');

module.exports = async function(callback) {
  try {
      let accounts = await utils.getAllAccounts(web3);
      let fsp = accounts[0];
      let instrumentType = argv.instrument;
      let instrumentRegistry = await InstrumentRegistry.deployed();
      console.log('InstrumentRegistry Address: ' + instrumentRegistry.address);
      let parametersUtil = await ParametersUtil.deployed();
      let instrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);

      // Activate Instrument
      console.log('Deploying instrument.');
      let instrument = await utils.getInstrumentCode(instrumentType, artifacts).new({from: fsp});
      await instrumentRegistry.activateInstrument(instrument.address, instrumentParameters, {from: fsp});
      const instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(instrument.address, {from: fsp});
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
