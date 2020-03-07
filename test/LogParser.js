const createCsvWriter = require('csv-writer').createObjectCsvWriter;

async function parse(log, events, timestampMapping) {
  let foundAbi = events.find(function(abi) {
    return (web3.eth.abi.encodeEventSignature(abi) == log.topics[0]);
  });
  if (foundAbi) {
    let args = web3.eth.abi.decodeLog(foundAbi.inputs, log.data, foundAbi.anonymous ? log.topics : log.topics.slice(1));
    if (!timestampMapping[log.blockNumber]) {
      let block = await web3.eth.getBlock(log.blockNumber);
      timestampMapping[log.blockNumber] = block.timestamp;
    }
    return {event: foundAbi.name, args: args, blockNumber: log.blockNumber, logIndex: log.logIndex, timestamp: timestampMapping[log.blockNumber]};
  }
  return null;
}

async function logParserWithTimestamp(logs, abi) {
  let result = [];
  let timestampMapping = {};
  let events = abi.filter(function (json) {
    return json.type === 'event';
  });
  for (let log of logs) {
    let parsedLog = await parse(log, events, timestampMapping);
    if (parsedLog != null) {
      result.push(parsedLog);
    }
  }
  return result;
}

function logParser (logs, abi) {
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

async function generateCSV(logs, issuanceId, location, accountMappings) {
  let csvWriter = createCsvWriter({
    path: location,
    header: [
      {id: 'BlockHeight', title: 'Block Height'},
      {id: 'timestamp', title: 'timestamp'},
      {id: 'Address', title: 'Address'},
      {id: 'Role', title: 'Role'},
      {id: 'Wallet', title: 'Wallet'},
      {id: 'InstrumentEscrowToken', title: 'Instrument Escrow Token'},
      {id: 'InstrumentEscrowAmount', title: 'Instrument Escrow Amount'},
      {id: 'IssuanceEscrowToken', title: 'Issuance Escrow Token'},
      {id: 'IssuanceEscrowAmount', title: 'Issuance Escrow Amount'},
      {id: 'ID', title: 'ID'},
      {id: 'Type', title: 'Type'},
      {id: 'Token', title: 'Token'},
      {id: 'Amount', title: 'Amount'},
      {id: 'Counterpart', title: 'Counterpart'},
      {id: 'CounterpartAddress', title: 'Counterpart Address'},
      {id: 'DueTimestamp', title: 'Due Timestamp'},
      {id: 'State', title: 'State'},
      {id: 'ReinitiatedTo', title: 'Reinitiated To'}
    ]
  });
  await csvWriter.writeRecords(generateTransferLogs(logs, issuanceId, accountMappings));
}

function processTokenDeposited(log, result, targetIssuanceId, instrumentEscrowBalance, issuanceEscrowBalance, accountMappings) {
  let amount = parseInt(log['args']['amount']);
  let tokenAddress = log['args']['token'];
  let depositer = log['args']['depositer'];
  instrumentEscrowBalance[depositer] = instrumentEscrowBalance[depositer] || {};
  instrumentEscrowBalance[depositer][tokenAddress] = instrumentEscrowBalance[depositer][tokenAddress] || 0;
  instrumentEscrowBalance[depositer][tokenAddress] += amount;
  let baseEntry = {
    BlockHeight: log.blockNumber,
    timestamp: new Date(parseInt(log.timestamp) * 1000).toISOString(),
    Address: depositer,
    Role: accountMappings[depositer],
    Wallet: "Deposit"
  };
  return result.concat(populateBalanceEntry(instrumentEscrowBalance, issuanceEscrowBalance, depositer, baseEntry));
}

function processTokenWithdrawn(log, result, targetIssuanceId, instrumentEscrowBalance, issuanceEscrowBalance, accountMappings) {
  let amount = parseInt(log['args']['amount']);
  let tokenAddress = log['args']['token'];
  let withdrawer = log['args']['withdrawer'];
  instrumentEscrowBalance[withdrawer][tokenAddress] -= amount;
  let baseEntry = {
    BlockHeight: log.blockNumber,
    timestamp: new Date(parseInt(log.timestamp) * 1000).toISOString(),
    Address: withdrawer,
    Role: accountMappings[withdrawer],
    Wallet: "Withdraw"
  };
  return result.concat(populateBalanceEntry(instrumentEscrowBalance, issuanceEscrowBalance, depositer, baseEntry));
}

function processTransfers(log, result, targetIssuanceId, instrumentEscrowBalance, issuanceEscrowBalance, accountMappings) {
  let issuanceId = log['args']['issuanceId'];
  let tokenAddress = log['args']['tokenAddress'];
  let fromAddress = log['args']['fromAddress'];
  let toAddress = log['args']['toAddress'];
  let amount = parseInt(log['args']['amount']);
  let transferType = parseInt(log['args']['transferType']);
  if (transferType === 1) {
    instrumentEscrowBalance[fromAddress][tokenAddress] -= amount;
    if (issuanceId === targetIssuanceId) {
      issuanceEscrowBalance[fromAddress] = issuanceEscrowBalance[fromAddress] || {};
      issuanceEscrowBalance[fromAddress][tokenAddress] = issuanceEscrowBalance[fromAddress][tokenAddress] || 0;
      issuanceEscrowBalance[fromAddress][tokenAddress] += amount;
    }
    let baseEntry = {
      BlockHeight: log.blockNumber,
      timestamp: new Date(parseInt(log.timestamp) * 1000).toISOString(),
      Address: fromAddress,
      Role: accountMappings[fromAddress],
      Wallet: ""
    };
    result = result.concat(populateBalanceEntry(instrumentEscrowBalance, issuanceEscrowBalance, fromAddress, baseEntry));
  }
  if (transferType === 2) {
    instrumentEscrowBalance[fromAddress] = instrumentEscrowBalance[fromAddress] || {};
    instrumentEscrowBalance[fromAddress][tokenAddress] = instrumentEscrowBalance[fromAddress][tokenAddress] || 0;
    instrumentEscrowBalance[fromAddress][tokenAddress] += amount;
    if (issuanceId === targetIssuanceId) {
      issuanceEscrowBalance[fromAddress][tokenAddress] -= amount;
    }
    let baseEntry = {
      BlockHeight: log.blockNumber,
      timestamp: new Date(parseInt(log.timestamp) * 1000).toISOString(),
      Address: fromAddress,
      Role: accountMappings[fromAddress],
      Wallet: ""
    };
    result = result.concat(populateBalanceEntry(instrumentEscrowBalance, issuanceEscrowBalance, fromAddress, baseEntry));
  }
  if (transferType === 3) {
    if (issuanceId === targetIssuanceId) {
      issuanceEscrowBalance[fromAddress][tokenAddress] -= amount;
      issuanceEscrowBalance[toAddress] = issuanceEscrowBalance[toAddress] || {};
      issuanceEscrowBalance[toAddress][tokenAddress] = issuanceEscrowBalance[toAddress][tokenAddress] || 0;
      issuanceEscrowBalance[toAddress][tokenAddress] += amount;

      let baseEntry = {
        BlockHeight: log.blockNumber,
        timestamp: new Date(parseInt(log.timestamp) * 1000).toISOString(),
        Address: fromAddress,
        Role: accountMappings[fromAddress],
        Wallet: ""
      };
      result = result.concat(populateBalanceEntry(instrumentEscrowBalance, issuanceEscrowBalance, fromAddress, baseEntry));
      baseEntry = {
        BlockHeight: log.blockNumber,
        timestamp: new Date(parseInt(log.timestamp) * 1000).toISOString(),
        Address: toAddress,
        Role: accountMappings[toAddress],
        Wallet: ""
      };
      result = result.concat(populateBalanceEntry(instrumentEscrowBalance, issuanceEscrowBalance, toAddress, baseEntry));
    }
  }
  return result;
}

function parseLineItemState(state) {
  if (state == '1') {
    return "Unpaid";
  }
  if (state == '2') {
    return "Paid";
  }
  if (state == '3') {
    return "Reinitiated";
  }
}

function parseLineItemType(type) {
  if (type == '1') {
    return "Payable";
  }
}

function processLineItemCreated(log, result, targetIssuanceId, payableMappings, accountMappings) {
  let issuanceId = log['args']['issuanceId'];
  if (issuanceId != targetIssuanceId) {
    return result;
  }
  let itemId = log['args']['itemId'];
  let state = parseLineItemState(log['args']['state']);
  let itemType = parseLineItemType(log['args']['itemType']);
  let obligatorAddress = log['args']['obligatorAddress'];
  let claimorAddress = log['args']['claimorAddress'];
  let tokenAddress = log['args']['tokenAddress'];
  let dueTimestamp = log['args']['dueTimestamp'];
  let amount = parseInt(log['args']['amount']);
  let reinitiatedTo = log['args']['reinitiatedTo'];
  if (reinitiatedTo == '0') {
    reinitiatedTo = null;
  }
  let baseEntry = {
    BlockHeight: log.blockNumber,
    timestamp: new Date(parseInt(log.timestamp) * 1000).toISOString(),
    Address: obligatorAddress,
    Role: accountMappings[obligatorAddress],
    Wallet: "",
    ID: itemId,
    Type: itemType,
    Token: tokenAddress,
    Amount: amount,
    CounterpartAddress: claimorAddress,
    Counterpart: accountMappings[claimorAddress],
    DueTimestamp: dueTimestamp,
    State: state,
    ReinitiatedTo: reinitiatedTo
  };
  payableMappings[itemId] = baseEntry;
  return result.concat(JSON.parse(JSON.stringify(baseEntry)));
}

function processLineItemUpdated(log, result, targetIssuanceId, payableMappings, accountMappings) {
  let issuanceId = log['args']['issuanceId'];
  if (issuanceId != targetIssuanceId) {
    return result;
  }
  let itemId = log['args']['itemId'];
  let state = parseLineItemState(log['args']['state']);
  let reinitiatedTo = log['args']['reinitiatedTo'];
  if (reinitiatedTo == '0') {
    reinitiatedTo = null;
  }
  let baseEntry = payableMappings[itemId];
  baseEntry["State"] = state;
  baseEntry["ReinitiatedTo"] = reinitiatedTo;
  payableMappings[itemId] = baseEntry;
  return result.concat(JSON.parse(JSON.stringify(baseEntry)));
}

function generateTransferLogs(logs, targetIssuanceId, accountMappings) {
  let instrumentEscrowBalance = {};
  let issuanceEscrowBalance = {};
  let payableMappings = {};
  let result = [];
  for (let log of logs) {
    if (log['event'] == 'TokenDeposited') {
      result = processTokenDeposited(log, result, targetIssuanceId, instrumentEscrowBalance, issuanceEscrowBalance, accountMappings);
    }
    if (log['event'] == 'TokenWithdrawn') {
      result = processTokenWithdrawn(log, result, targetIssuanceId, instrumentEscrowBalance, issuanceEscrowBalance, accountMappings);
    }
    if (log['event'] == 'TokenTransferred') {
      result = processTransfers(log, result, targetIssuanceId, instrumentEscrowBalance, issuanceEscrowBalance, accountMappings);
    }
    if (log['event'] == 'SupplementalLineItemCreated') {
      result = processLineItemCreated(log, result, targetIssuanceId, payableMappings, accountMappings);
    }
    if (log['event'] == 'SupplementalLineItemUpdated') {
      result = processLineItemUpdated(log, result, targetIssuanceId, payableMappings, accountMappings);
    }
  }
  return result;
}

function getBalance(entries, user, token) {
  let accountBalance = entries[user] || {};
  return accountBalance[token] || 0;
}

function populateBalanceEntry(instrumentEscrowBalance, issuanceEscrowBalance, user, baseEntry) {
  let result = [];
  let keys = new Set([].concat(Object.keys(instrumentEscrowBalance[user] || {}), Object.keys(issuanceEscrowBalance[user] || {})));
  for (let key of keys) {
    let finalEntry = {};
    Object.assign(finalEntry, baseEntry);
    let instrumentEscrowAmount = getBalance(instrumentEscrowBalance, user, key);
    let issuanceEscrowAmount = getBalance(issuanceEscrowBalance, user, key);
    let balanceEntry = {
      InstrumentEscrowToken: key,
      InstrumentEscrowAmount: instrumentEscrowAmount,
      IssuanceEscrowToken: key,
      IssuanceEscrowAmount: issuanceEscrowAmount,
    };
    Object.assign(finalEntry, balanceEntry);
    result.push(finalEntry);
  }
  return result;
}

module.exports = {
  logParser: logParser,
  logParserWithTimestamp: logParserWithTimestamp,
  generateCSV: generateCSV
};
