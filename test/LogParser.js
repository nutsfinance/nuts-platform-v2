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

module.exports = {
  logParser: logParser
};
