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
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function createIssuance(bytes memory issuanceParametersData, bytes memory makerParametersData) public
        returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);

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
     * @param amount The amount of ERC20 token to deposit.
     * @param data The data for this issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(bytes memory issuanceParametersData, address tokenAddress, uint256 amount, bytes memory data) public
        returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);


    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     * @param amount The amount of ERC20 token to withdraw.
     * @param data The data for this issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenWithdraw(bytes memory issuanceParametersData, address tokenAddress, uint256 amount, bytes memory data)
        public returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);

    /**
     * @dev A custom event is triggered.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @param data The data for this issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(bytes memory issuanceParametersData, bytes32 eventName, bytes memory eventPayload, bytes memory data)
        public returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData);
}