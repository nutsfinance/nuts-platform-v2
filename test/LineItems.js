function isLineItemMatch(lineItem, itemJson) {
  return lineItem.getId().toNumber() == itemJson['id'] &&
    lineItem.getLineitemtype() == itemJson['lineItemType'] &&
    lineItem.getState() == itemJson['state'] &&
    lineItem.getObligatoraddress().toAddress().toLowerCase() == itemJson['obligatorAddress'].toLowerCase() &&
    lineItem.getClaimoraddress().toAddress().toLowerCase() == itemJson['claimorAddress'].toLowerCase() &&
    lineItem.getTokenaddress().toAddress().toLowerCase() == itemJson['tokenAddress'].toLowerCase() &&
    lineItem.getAmount().toNumber() == itemJson['amount'] &&
    lineItem.getDuetimestamp().toNumber() == itemJson['dueTimestamp'] &&
    lineItem.getReinitiatedto().toNumber() == itemJson['reinitiatedTo'];
}

function searchLineItems(items, itemJson) {
  return items.filter(item => isLineItemMatch(item, itemJson));
}

function getLineItemJson(lineItem) {
  return {
    id: lineItem.getId().toNumber(),
    lineItemType: lineItem.getLineitemtype(),
    state: lineItem.getState(),
    obligatorAddress: lineItem.getObligatoraddress().toAddress(),
    claimorAddress: lineItem.getClaimoraddress().toAddress(),
    tokenAddress: lineItem.getTokenaddress().toAddress(),
    amount: lineItem.getAmount().toNumber(),
    dueTimestamp: lineItem.getDuetimestamp().toNumber(),
    reinitiatedTo: lineItem.getReinitiatedto().toNumber()
  };
}

module.exports = {
  searchLineItems: searchLineItems,
  getLineItemJson: getLineItemJson
};
