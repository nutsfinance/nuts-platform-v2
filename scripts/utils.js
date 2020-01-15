function getAllAccounts(web3) {
  return new Promise((resolve, reject) => {
    web3.eth.getAccounts((err, acc) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(acc);
      });
  });
}

function getInstrumentCode(instrument, artifacts) {
  let instrumentType = instrument.toLowerCase();
  if (instrumentType === 'saving') {
    return artifacts.require('./instrument/saving/Saving.sol');
  }
  if (instrumentType === 'lending') {
    return artifacts.require('./instrument/lending/Lending.sol');
  }
  if (instrumentType === 'spotswap') {
    return artifacts.require('./instrument/swap/SpotSwap.sol');
  }
  if (instrumentType === 'borrowing') {
    return artifacts.require('./instrument/borrowing/Borrowing.sol');
  }
  throw "unsupported instrument";
}

function getInstrumentParameters(argv, parametersUtil) {
  let instrumentType = argv.instrument;
  if (instrumentType === 'lending') {
    return parametersUtil.getLendingMakerParameters(argv.collateralTokenAddress,
        argv.lendingTokenAddress, argv.lendingAmount, argv.collateralRatio, argv.tenorDays, argv.interestRate);
  }
  if (instrumentType === 'spotswap') {
    return parametersUtil.getSpotSwapMakerParameters(argv.inputTokenAddress, argv.outputTokenAddress, argv.inputAmount, argv.outputAmount, argv.duration);
  }
  if (instrumentType === 'borrowing') {
    return parametersUtil.getBorrowingMakerParameters(argv.collateralTokenAddress,
        argv.borrowingTokenAddress, argv.borrowingAmount, argv.collateralRatio, argv.tenorDays, argv.interestRate);
  }
  throw "unsupported instrument";
}

module.exports = {
  getInstrumentCode: getInstrumentCode,
  getAllAccounts: getAllAccounts,
  getInstrumentParameters: getInstrumentParameters
};
