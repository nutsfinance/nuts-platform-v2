pragma solidity ^0.5.0;

import "../../lib/proxy/AdminOnlyUpgradeabilityProxy.sol";
import "../InstrumentManagerBase.sol";
import "../InstrumentBase.sol";
import "./InstrumentV3.sol";

/**
 * @title Instrument Manager for Instrument v3.
 */
contract InstrumentV3Manager is InstrumentManagerBase {

    // Mapping: Issuance Id => Issuance Proxy contract address
    mapping(uint256 => address) private _issuanceProxies;

    /**
     * @dev Instrument type-specific issuance creation processing.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     */
    function _processCreateIssuance(uint256 issuanceId, bytes memory issuanceParametersData) internal
        returns (InstrumentBase.IssuanceStates updatedState) {

        // Create an AdminOnlyUpgradeabilityProxy for the new issuance
        // Current Instrument Manager is the proxy admin for this proxy, and only the current
        // Instrument Manager can call fallback on the proxy.
        AdminOnlyUpgradeabilityProxy proxy = new AdminOnlyUpgradeabilityProxy(_instrumentAddress, address(this), new bytes(0));
        _issuanceProxies[issuanceId] = address(proxy);

        updatedState = InstrumentV3(_issuanceProxies[issuanceId]).createIssuance(issuanceParametersData);
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

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).engageIssuance(issuanceId,
            takerAddress, takerParameters, state, escrow);
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

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).processTokenDeposit(issuanceId,
            fromAddress, tokenAddress, amount, state, escrow);
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

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).processTokenWithdraw(issuanceId,
            toAddress, tokenAddress, amount, state, escrow);
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

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).processCustomEvent(issuanceId,
            notifierAddress, eventName, eventPayload, state, escrow);
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

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).processScheduledEvent(issuanceId,
            notifierAddress, eventName, eventPayload, state, escrow);
    }
}