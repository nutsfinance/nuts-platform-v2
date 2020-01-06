const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
const ERC20 = artifacts.require('../lib/token/ERC20.sol');
const argv = require('yargs').argv;
const utils = require('./utils');

module.exports = async function(callback) {
  try {
    let priceOracle = await PriceOracle.deployed();
    await priceOracle.setRate(argv.firstTokenAddress, argv.secondTokenAddress, 1, argv.ratio);
    await priceOracle.setRate(argv.secondTokenAddress, argv.firstTokenAddress, 1, argv.ratio);
    callback();
  } catch (e) {
    callback(e);
  }
}
