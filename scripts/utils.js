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

function logParser (web3, logs, abi) {
  let events = abi.filter(function (json) {
    return json.type === 'event';
  });

  return logs.map(function (log) {
    let foundAbi = events.find(function(abi) {
      return (web3.eth.abi.encodeEventSignature(abi) == log.topics[0]);
    });
    if (foundAbi) {
      let args = web3.eth.abi.decodeLog(foundAbi.inputs, log.data, foundAbi.anonymous ? log.topics : log.topics.slice(1));
      return {event: foundAbi.name, args: args};
    }
    return null;
  }).filter(p => p != null);
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
  getInstrumentParameters: getInstrumentParameters,
  logParser: logParser
};
