pragma solidity ^0.5.0;

import "../InstrumentBase.sol";
import "../../escrow/EscrowBaseInterface.sol";

/**
 * Instrument v3 base contract.
 * A storage proxy is created for each issuance.
 */
contract InstrumentV3 is InstrumentBase {

    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceParametersData Issuance Parameters.
     * @return updatedState The new state of the issuance.
     */
    function createIssuance(bytes memory issuanceParametersData) public returns (IssuanceStates updatedState);

    /**
     * @dev A taker engages to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @return updatedState The new state of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(bytes memory issuanceParametersData) public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     * @param issuanceId The id of the issuance
     * @param fromAddress The address of the ERC20 token sender.
     * @param tokenAddress The address of the ERC20 token deposited.
     * @param amount The amount of ERC20 token deposited.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(uint256 issuanceId, address fromAddress, address tokenAddress, uint256 amount,
        IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);


    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     * @param issuanceId The id of the issuance
     * @param toAddress The address of the ERC20 token withdrawer.
     * @param tokenAddress The address of the ERC20 token withdrawn.
     * @param amount The amount of ERC20 token withdrawn.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenWithdraw(uint256 issuanceId, address toAddress, address tokenAddress, uint256 amount,
        IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev A custom event is triggered.
     * @param issuanceId The id of the issuance
     * @param notifierAddress The address of the caller who notifies the custom event.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload,
        IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev A scheduled event is triggered.
     * @param issuanceId The id of the issuance
     * @param notifierAddress The address of the caller who notifies the scheduled event.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processScheduledEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload,
        IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);
}