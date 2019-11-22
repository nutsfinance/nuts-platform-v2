pragma solidity ^0.5.0;

import "../lib/protobuf/IssuanceData.sol";
import "../lib/protobuf/SupplementalLineItem.sol";
import "../lib/protobuf/TokenTransfer.sol";
import "./InstrumentInterface.sol";

/**
 * @title Base contract for instruments.
 */
contract InstrumentBase is InstrumentInterface {
    /**
     * @dev The event used to schedule contract events after specific time.
     * @param issuanceId The id of the issuance
     * @param timestamp After when the issuance should be notified
     * @param eventName The name of the custom event
     * @param eventPayload The payload the custom event
     */
    event EventTimeScheduled(uint256 indexed issuanceId, uint256 timestamp, bytes32 eventName, bytes eventPayload);

    /**
     * @dev The event used to schedule contract events after specific block.
     * @param issuanceId The id of the issuance
     * @param blockNumber After which block the issuance should be notified
     * @param eventName The name of the custom event
     * @param eventPayload The payload the custom event
     */
    event EventBlockScheduled(uint256 indexed issuanceId, uint256 blockNumber, bytes32 eventName, bytes eventPayload);

    event SupplementalLineItemCreated(uint256 indexed issuanceId, uint8 indexed itemId, SupplementalLineItem.Type itemType,
        SupplementalLineItem.State state, address obligatorAddress, address claimorAddress, address tokenAddress, uint256 amount,
        uint256 dueTimestamp);

    event SupplementalLineItemUpdated(uint256 indexed issuanceId, uint8 indexed itemId, SupplementalLineItem.State state, uint8 reinitiatedTo);

    // Scheduled custom events
    bytes32 constant internal ENGAGEMENT_DUE_EVENT = "engagement_due";
    bytes32 constant internal ISSUANCE_DUE_EVENT = "issuance_due";

    // Custom events
    bytes32 constant internal CANCEL_ISSUANCE_EVENT = "cancel_issuance";

    // Common properties shared by all issuances
    uint256 internal _issuanceId;
    address internal _fspAddress;
    address internal _brokerAddress;
    address internal _instrumentEscrowAddress;
    address internal _issuanceEscrowAddress;
    address internal _priceOracleAddress;
    address internal _makerAddress;
    address internal _takerAddress;
    uint256 internal _creationTimestamp;
    uint256 internal _engagementTimestamp;
    uint256 internal _engagementDueTimestamp;
    uint256 internal _issuanceDueTimestamp;
    uint256 internal _settlementTimestamp;
    IssuanceProperties.State internal _state;
    // List of supplemental line items
    mapping(uint8 => SupplementalLineItem.Data) internal _supplementalLineItems;
    uint8[] internal _supplementalLineItemIds;

    /**
     * @dev Initializes an issuance with common parameters.
     * @param issuanceId ID of the issuance.
     * @param fspAddress Address of the FSP who creates the issuance.
     * @param brokerAddress Address of the instrument broker.
     * @param instrumentEscrowAddress Address of the instrument escrow.
     * @param issuanceEscrowAddress Address of the issuance escrow.
     * @param priceOracleAddress Address of the price oracle.
     */
    function initialize(uint256 issuanceId, address fspAddress, address brokerAddress, address instrumentEscrowAddress,
        address issuanceEscrowAddress, address priceOracleAddress) public {
        require(_issuanceId == 0, 'Already initialized');
        _issuanceId = issuanceId;
        _fspAddress = fspAddress;
        _brokerAddress = brokerAddress;
        _instrumentEscrowAddress = instrumentEscrowAddress;
        _issuanceEscrowAddress = issuanceEscrowAddress;
        _priceOracleAddress = priceOracleAddress;
        _state = IssuanceProperties.State.Initiated;
    }

    /**
     * @dev Checks whether the issuance is terminated. No futher action is taken on a terminated issuance.
     */
    function isTerminated() public view returns (bool) {
        return _state == IssuanceProperties.State.Unfunded ||
            _state == IssuanceProperties.State.Cancelled ||
            _state == IssuanceProperties.State.CompleteNotEngaged ||
            _state == IssuanceProperties.State.CompleteEngaged ||
            _state == IssuanceProperties.State.Delinquent;
    }

    /**
     * @dev Create a new issuance of the financial instrument
     */
    function createIssuance(address /** callerAddress */, bytes memory /** makerParametersData */) public returns (bytes memory) {
        revert('Unsupported operation');
    }

    /**
     * @dev A taker engages to the issuance
     */
    function engageIssuance(address /** callerAddress */, bytes memory /** takerParameters */) public returns (bytes memory) {
        revert('Unsupported operation');
    }

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     */
    function processTokenDeposit(address /** callerAddress */, address /** tokenAddress */, uint256 /** amount */)
        public returns (bytes memory)  {
        revert('Unsupported operation');
    }


    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     */
    function processTokenWithdraw(address /** callerAddress */, address /** tokenAddress */, uint256 /** amount */)
        public returns (bytes memory)  {
        revert('Unsupported operation');
    }

    /**
     * @dev A custom event is triggered.
     */
    function processCustomEvent(address /** callerAddress */, bytes32 /** eventName */, bytes memory /** eventPayload */)
        public returns (bytes memory) {
        revert('Unsupported operation');
    }

    /**
     * @dev Get custom data.
     */
    function getCustomData(address /** callerAddress */, bytes32 /** dataName */) public view returns (bytes memory) {
        revert('Unsupported operation');
    }

    /**
     * @dev Returns the common properties about the issuance.
     */
    function _getIssuanceProperties() internal view returns (IssuanceProperties.Data memory) {
        SupplementalLineItem.Data[] memory supplementalLineItems = new SupplementalLineItem.Data[](_supplementalLineItemIds.length);
        for (uint i = 0; i < _supplementalLineItemIds.length; i++) {
            supplementalLineItems[i] = _supplementalLineItems[_supplementalLineItemIds[i]];
        }
        return IssuanceProperties.Data({
            issuanceId: _issuanceId,
            makerAddress: _makerAddress,
            takerAddress: _takerAddress,
            engagementDueTimestamp: _engagementDueTimestamp,
            issuanceDueTimestamp: _issuanceDueTimestamp,
            creationTimestamp: _creationTimestamp,
            engagementTimestamp: _engagementTimestamp,
            settlementTimestamp: _settlementTimestamp,
            issuanceProxyAddress: address(this),
            issuanceEscrowAddress: _issuanceEscrowAddress,
            state: _state,
            supplementalLineItems: supplementalLineItems
        });
    }

    /**
     * @dev Create a new inbound transfer action.
     */
    function _createInboundTransfer(address account, address tokenAddress, uint256 amount) internal pure returns (Transfer.Data memory) {
        Transfer.Data memory transfer = Transfer.Data({
            transferType: Transfer.Type.Inbound,
            fromAddress: account,
            toAddress: account,
            tokenAddress: tokenAddress,
            amount: amount
        });
        return transfer;
    }

    /**
     * @dev Create a new outbound transfer action.
     */
    function _createOutboundTransfer(address account, address tokenAddress, uint256 amount) internal pure returns (Transfer.Data memory) {
        Transfer.Data memory transfer = Transfer.Data({
            transferType: Transfer.Type.Outbound,
            fromAddress: account,
            toAddress: account,
            tokenAddress: tokenAddress,
            amount: amount
        });
        return transfer;
    }

    /**
     * @dev Create a new intra-issuance transfer action.
     */
    function _createIntraIssuanceTransfer(address fromAddress, address toAddress, address tokenAddress, uint256 amount)
        internal pure returns (Transfer.Data memory) {
        Transfer.Data memory transfer = Transfer.Data({
            transferType: Transfer.Type.IntraIssuance,
            fromAddress: fromAddress,
            toAddress: toAddress,
            tokenAddress: tokenAddress,
            amount: amount
        });
        return transfer;
    }

    /**
     * @dev Create new payable for the issuance.
     */
    function _createNewPayable(uint8 id, address obligatorAddress, address claimorAddress, address tokenAddress,
        uint256 amount, uint256 dueTimestamp) internal {
        _supplementalLineItemIds.push(id);
        _supplementalLineItems[id] = SupplementalLineItem.Data({
            id: id,
            lineItemType: SupplementalLineItem.Type.Payable,
            state: SupplementalLineItem.State.Unpaid,
            obligatorAddress: obligatorAddress,
            claimorAddress: claimorAddress,
            tokenAddress: tokenAddress,
            amount: amount,
            dueTimestamp: dueTimestamp,
            reinitiatedTo: 0
        });
        emit SupplementalLineItemCreated(_issuanceId, id, SupplementalLineItem.Type.Payable, SupplementalLineItem.State.Unpaid,
            obligatorAddress, claimorAddress, tokenAddress, amount, dueTimestamp);
    }

    /**
     * @dev Updates the existing payable for the issuance.
     */
    function _updatePayable(uint8 id, SupplementalLineItem.State state, uint8 reinitiatedTo) internal {
        _supplementalLineItems[id].state = state;
        _supplementalLineItems[id].reinitiatedTo = reinitiatedTo;
        emit SupplementalLineItemUpdated(_issuanceId, id, state, reinitiatedTo);
    }
}
