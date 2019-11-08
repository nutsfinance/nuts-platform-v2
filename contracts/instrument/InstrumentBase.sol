pragma solidity ^0.5.0;

/**
 * @title Base contract for instruments.
 */
contract InstrumentBase {

    // The states of an instrument.
    enum IssuanceStates {
        // The issuance is initiated. It should be the starting state.
        Initiated,
        // The issuance is ready for engagement
        Engageable,
        // The issuance is engaged
        Engaged,
        // The issuance fails to meet the requirements make it engageable.
        // Unfunded is a terminating state.
        Unfunded,
        // The issuance is cancelled by the maker.
        // Cancelled is a terminating state.
        Cancelled,
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
    event EventTimeScheduled(uint256 indexed issuanceId, uint256 timestamp, bytes32 eventName, bytes eventPayload);

    /**
     * @dev The event used to schedule contract events after specific block.
     * @param issuanceId The id of the issuance
     * @param blockNumber After which block the issuance should be notified
     * @param eventName The name of the custom event
     * @param eventPayload The payload the custom event
     */
    event EventBlockScheduled(uint256 indexed issuanceId, uint256 blockNumber, bytes32 eventName, bytes eventPayload);

    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceParametersData Issuance Parameters.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return updatedState The new state of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function createIssuance(bytes memory issuanceParametersData, bytes memory makerParametersData) public
        returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev A taker engages to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param takerParameters The custom parameters to the new engagement
     * @return updatedState The new state of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(bytes memory issuanceParametersData, bytes memory takerParameters) public
        returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(bytes memory issuanceParametersData, address tokenAddress, uint256 amount) public
        returns (IssuanceStates updatedState, bytes memory transfersData);


    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     * @param amount The amount of ERC20 token to withdraw.
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenWithdraw(bytes memory issuanceParametersData, address tokenAddress, uint256 amount)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev A custom event is triggered.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(bytes memory issuanceParametersData, bytes32 eventName, bytes memory eventPayload)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev Read custom data.
     * @param issuanceParametersData Issuance Parameters.
     * @param dataName The name of the custom data.
     * @return customData The custom data of the issuance.
     */
    function readCustomData(bytes memory issuanceParametersData, bytes32 dataName) public view returns (bytes memory);
}