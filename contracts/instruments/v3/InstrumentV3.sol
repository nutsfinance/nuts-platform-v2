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
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return updatedState The new state of the issuance.
     */
    function createIssuance(bytes memory issuanceParametersData, bytes memory makerParametersData) public
        returns (IssuanceStates updatedState);

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
    function processCustomEvent(bytes memory issuanceParametersData, string memory eventName, bytes memory eventPayload)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev A scheduled event is triggered.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processScheduledEvent(bytes memory issuanceParametersData, string memory eventName, bytes memory eventPayload)
        public returns (IssuanceStates updatedState, bytes memory transfersData);
}