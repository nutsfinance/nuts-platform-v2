pragma solidity ^0.5.0;

import "../instruments/InstrumentManagerBase.sol";

/**
 * @title Instrument Manager Mock.
 */
contract InstrumentV1Manager is InstrumentManagerBase {

    /**
     * @dev Instrument type-specific issuance creation processing.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param makerParametersData The custom parameters to the newly created issuance
     */
    function _processCreateIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory makerParametersData) internal
        returns (InstrumentBase.IssuanceStates updatedState) {
    }

    /**
     * @dev Instrument type-specific issuance engage processing.
     * @param issuanceId ID of the issuance.
     * @param takerParameters The custom parameters to the new engagement
     * @param issuanceParametersData Issuance Parameters.
     */
    function _processEngageIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory takerParameters)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {
    }

    /**
     * @dev Instrument type-specific issuance ERC20 token deposit processing.
     * Note: This method is called after deposit is complete, so that the Escrow reflects the balance after deposit.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     */
    function _processTokenDeposit(uint256 issuanceId, bytes memory issuanceParametersData, address tokenAddress, uint256 amount)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {
    }

    /**
     * @dev Instrument type-specific issuance ERC20 withdraw processing.
     * Note: This method is called after withdraw is complete, so that the Escrow reflects the balance after withdraw.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     * @param amount The amount of ERC20 token to withdraw.
     */
    function _processTokenWithdraw(uint256 issuanceId, bytes memory issuanceParametersData, address tokenAddress, uint256 amount)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {
    }

    /**
     * @dev Instrument type-specific custom event processing.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     */
    function _processCustomEvent(uint256 issuanceId, bytes memory issuanceParametersData, string memory eventName, bytes memory eventPayload)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {
    }

    /**
     * @dev Instrument type-specific scheduled event processing.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     */
    function _processScheduledEvent(uint256 issuanceId, bytes memory issuanceParametersData, string memory eventName, bytes memory eventPayload)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {
   }
}