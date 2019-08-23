pragma solidity ^0.5.0;

/**
 * @title Base contract for v1, v2, v3 instruments.
 */
contract Instrument {

    // The states of an instrument.
    enum IssuanceStates {
        // The issuance is initiated. It should be the starting state.
        Initiated,
        // The issuance is ready for engagement
        Engageable,
        // The issuance is active
        Active,
        // The issuance fails to meet the requirements make it engageable.
        // Unfunded is a terminating state.
        Unfunded,
        // The issuance is due with no engagement.
        // CompleteNotEngaged is a terminating state.
        CompleteNotEngaged,
        // The issuance is completed with active engagements.
        // ComplateEngaged is a terminating state.
        CompleteEngaged,
        // The issuance fails to meet the requirements to make it CompleteEngaged.
        // Deliquent is a terminating state.
        Delinquent
    }

    /**
     * @dev The event used to schedule contract events after specific time.
     * @param issuanceId The id of the issuance
     * @param timestamp After when the issuance should be notified
     * @param eventName The name of the custom event
     * @param eventPayload The payload the custom event
     */
    event EventTimeScheduled(uint256 indexed issuanceId, uint256 timestamp, string eventName, bytes eventPayload);

    /**
     * @dev The event used to schedule contract events after specific block.
     * @param issuanceId The id of the issuance
     * @param blockNumber After which block the issuance should be notified
     * @param eventName The name of the custom event
     * @param eventPayload The payload the custom event
     */
    event EventBlockScheduled(uint256 indexed issuanceId, uint256 blockNumber, string eventName, bytes eventPayload);

    /**
     * @dev Determines whether the issuance is in termination states.
     */
    function isTerminationState(IssuanceStates state) public pure returns (bool) {
        return state == IssuanceStates.Unfunded || state == IssuanceStates.CompleteNotEngaged
            || state == IssuanceStates.CompleteEngaged || state == IssuanceStates.Delinquent;
    }
}