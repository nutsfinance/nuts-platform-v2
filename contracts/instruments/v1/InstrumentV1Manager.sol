pragma solidity ^0.5.0;

import "../InstrumentManagerBase.sol";
import "../InstrumentBase.sol";
import "./InstrumentV1.sol";

contract InstrumentV1Manager is InstrumentManagerBase {
    // Mapping: Issuance Id => Issuance data
    mapping(uint256 => bytes) private _issuanceData;

    /**
     * @dev Instrument type-specific issuance creation processing.
     * @param issuanceId ID of the issuance.
     * @param makerAddress Address of the maker which creates the new issuance.
     * @param makerParameters Custom issuance parameters.
     */
    function _processCreateIssuance(uint256 issuanceId, address makerAddress, bytes memory makerParameters)
        internal returns (InstrumentBase.IssuanceStates updatedState) {

        (updatedState, _issuanceData[issuanceId]) = InstrumentV1(_instrumentAddress).createIssuance(issuanceId,
            makerAddress, makerParameters);
    }

    /**
     * @dev Instrument type-specific issuance engage processing.
     * @param issuanceId ID of the issuance.
     * @param takerAddress Address of the taker which engages the issuance.
     * @param takerParameters Custom engagement parameters.
     * @param state The current issuance state
     * @param escrow The Issuance Escrow for this issuance.
     */
    function _processEngageIssuance(uint256 issuanceId, address takerAddress, bytes memory takerParameters,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).engageIssuance(issuanceId,
            takerAddress, takerParameters, _issuanceData[issuanceId], state, escrow);
    }

    /**
     * @dev Instrument type-specific issuance settle processing.
     * @param issuanceId ID of the issuance.
     * @param settlerAddress Address of the caller who triggers settlement.
     * @param settlerParameters Custom settlement parameters.
     * @param state The current issuance state
     * @param escrow The Issuance Escrow for this issuance.
     */
    function _processSettleIssuance(uint256 issuanceId, address settlerAddress, bytes memory settlerParameters,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).settleIssuance(issuanceId,
            settlerAddress, settlerParameters, _issuanceData[issuanceId], state, escrow);
    }

    /**
     * @dev Instrument type-specific issuance ETH deposit processing.
     * Note: This method is called after deposit is complete, so that the Escrow reflects the balance after deposit.
     * @param issuanceId ID of the issuance.
     * @param fromAddress Address whose balance is the ETH transferred from.
     * @param amount Amount of ETH deposited.
     * @param state The current issuance state.
     * @param escrow The Issuance Escrow for this issuance.
     */
    function _processDeposit(uint256 issuanceId, address fromAddress, uint256 amount,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).processDeposit(issuanceId,
            fromAddress, amount, _issuanceData[issuanceId], state, escrow);
    }

    /**
     * @dev Instrument type-specific issuance ERC20 token deposit processing.
     * Note: This method is called after deposit is complete, so that the Escrow reflects the balance after deposit.
     * @param issuanceId ID of the issuance.
     * @param fromAddress Address whose balance is the ERC20 token transferred from.
     * @param tokenAddress Address the deposited ERC20 token.
     * @param amount Amount of ERC20 deposited.
     * @param state The current issuance state.
     * @param escrow The Issuance Escrow for this issuance.
     */
    function _processTokenDeposit(uint256 issuanceId, address fromAddress, address tokenAddress, uint256 amount,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).processTokenDeposit(issuanceId,
            fromAddress, tokenAddress, amount, _issuanceData[issuanceId], state, escrow);
    }

    /**
     * @dev Instrument type-specific issuance ETH withdraw processing.
     * Note: This method is called after withdraw is complete, so that the Escrow reflects the balance after withdraw.
     * @param issuanceId ID of the issuance.
     * @param toAddress Address whose balance is ETH transferred to.
     * @param amount Amount of ETH transferred.
     * @param state The current issuance state.
     * @param escrow Issuance Escrow for this issuance.
     */
    function _processWithdraw(uint256 issuanceId, address toAddress, uint256 amount,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, _issuanceData[issuanceId], transfersData) = InstrumentV1(_instrumentAddress).processWithdraw(issuanceId,
            toAddress, amount, _issuanceData[issuanceId], state, escrow);
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