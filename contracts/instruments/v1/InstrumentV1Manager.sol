pragma solidity ^0.5.0;

import "../InstrumentManagerBase.sol";
import "../InstrumentBase.sol";
import "./InstrumentV1.sol";

/**
 * @title Instrument Manager for Instrument v1.
 */
contract InstrumentV1Manager is InstrumentManagerBase {
    // Mapping: Issuance Id => Issuance data
    mapping(uint256 => bytes) private _issuanceData;

    /**
     * @dev Instrument type-specific issuance creation processing.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param makerParameters The custom parameters to the newly created issuance
     */
    function _processCreateIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory makerParameters) internal
        returns (InstrumentBase.IssuanceStates updatedState) {

        (updatedState, _issuanceData[issuanceId]) = InstrumentV1(_instrumentAddress)
            .createIssuance(issuanceParametersData, makerParameters);
    }

    /**
     * @dev Instrument type-specific issuance engage processing.
     * @param issuanceId ID of the issuance.
     * @param takerParameters The custom parameters to the new engagement
     * @param issuanceParametersData Issuance Parameters.
     */
    function _processEngageIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory takerParameters)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress)
            .engageIssuance(issuanceParametersData, takerParameters, _issuanceData[issuanceId]);
    }

    /**
     * @dev Instrument type-specific issuance ERC20 token deposit processing.
     * Note: This method is called after deposit is complete, so that the Escrow reflects the balance after deposit.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token deposited.
     */
    function _processTokenDeposit(uint256 issuanceId, bytes memory issuanceParametersData, address tokenAddress, uint256 amount)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).processTokenDeposit(
            issuanceParametersData, tokenAddress, amount, _issuanceData[issuanceId]);
    }

    /**
     * @dev Instrument type-specific issuance ERC20 withdraw processing.
     * Note: This method is called after withdraw is complete, so that the Escrow reflects the balance after withdraw.
     * @param issuanceId ID of the issuance.
     * @param toAddress Address whose balance is the ERC20 token transferred to.
     * @param tokenAddress The ERC20 token to withdraw.
     * @param amount Amount of ERC20 token to withdraw.
     * @param state The current issuance state.
     * @param escrow The Issuance Escrow for this issuance.
     */
    function _processTokenWithdraw(uint256 issuanceId, address toAddress, address tokenAddress, uint256 amount,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).processTokenWithdraw(issuanceId,
            toAddress, tokenAddress, amount, _issuanceData[issuanceId], state, escrow);
    }

    /**
     * @dev Instrument type-specific custom event processing.
     * @param issuanceId ID of the issuance.
     * @param notifierAddress Address of the caller who notifies this custom event
     * @param eventName Name of the custom event
     * @param eventPayload Custom parameters for this custom event.
     * @param state The current issuance state.
     * @param escrow The Issuance Escrow for this issuance.
     */
    function _processCustomEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).processCustomEvent(issuanceId,
            notifierAddress, eventName, eventPayload, _issuanceData[issuanceId], state, escrow);
    }

    /**
     * @dev Instrument type-specific scheduled event processing.
     * @param issuanceId ID of the issuance.
     * @param notifierAddress Address of the caller who notifies this scheduled event.
     * @param eventName Name of the schedule event
     * @param eventPayload Custom parameters for this scheduled event
     * @param state The current issuance state
     * @param escrow The Issuance Escrow for this issuance
     */
    function _processScheduledEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).processScheduledEvent(issuanceId,
            notifierAddress, eventName, eventPayload, _issuanceData[issuanceId], state, escrow);
    }
}