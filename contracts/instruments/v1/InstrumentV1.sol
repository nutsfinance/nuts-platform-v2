pragma solidity ~0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../InstrumentBase.sol";

/**
 * @title Instrument v1 base contract.
 * All issuance data are passed in and returned as a string.
 */
contract InstrumentV1 is InstrumentBase {
    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceParametersData Issuance Parameters.
     * @param makerParameters The custom parameters to the newly created issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     */
    function createIssuance(bytes memory issuanceParametersData, bytes memory makerParameters) public
        returns (IssuanceStates updatedState, bytes memory updatedData);

    /**
     * @dev A taker engages to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param takerParameters The custom parameters to the new engagement
     * @param data The custom data for this issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(bytes memory issuanceParametersData, bytes memory takerParameters, bytes memory data) public
        returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token deposited.
     * @param data The data for this issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(bytes memory issuanceParametersData, address tokenAddress, uint256 amount, bytes memory data) public
        returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);


    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     * @param issuanceId The id of the issuance
     * @param toAddress The address of the ERC20 token withdrawer.
     * @param tokenAddress The address of the ERC20 token withdrawn.
     * @param amount The amount of ERC20 token withdrawn.
     * @param data The data for this issuance
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenWithdraw(uint256 issuanceId, address toAddress, address tokenAddress, uint256 amount,
        bytes memory data, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);

    /**
     * @dev A custom event is triggered.
     * @param issuanceId The id of the issuance
     * @param notifierAddress The address of the caller who notifies the custom event.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @param data The data for this issuance
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload,
        bytes memory data, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);

    /**
     * @dev A scheduled event is triggered.
     * @param issuanceId The id of the issuance
     * @param notifierAddress The address of the caller who notifies the scheduled event.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @param data The data for this issuance
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processScheduledEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload,
        bytes memory data, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);
}