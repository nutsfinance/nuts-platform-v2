pragma solidity ^0.5.0;

import "../../lib/proxy/AdminOnlyUpgradeabilityProxy.sol";
import "../InstrumentManagerBase.sol";
import "../InstrumentBase.sol";
import "./InstrumentV3.sol";

/**
 * @title Instrument Manager for Instrument v3.
 * A storage proxy is created for each issuance.
 */
contract InstrumentV3Manager is InstrumentManagerBase {

    // Mapping: Issuance Id => Issuance Proxy contract address
    mapping(uint256 => address) private _issuanceProxies;

    /**
     * @param fspAddress Address of FSP that activates this financial instrument.
     * @param instrumentAddress Address of the financial instrument contract.
     * @param instrumentConfigAddress Address of the Instrument Config contract.
     * @param instrumentParameters Custom parameters for the Instrument Manager.
     */
    constructor(address fspAddress, address instrumentAddress, address instrumentConfigAddress, bytes memory instrumentParameters)
        InstrumentManagerBase(fspAddress, instrumentAddress, instrumentConfigAddress, instrumentParameters) public {}


    /**
     * @dev Returns the address of all proxies.
     */
    function getIssuanceAddresses() public view returns (address[] memory) {
        address[] memory issuanceAddresses = new address[](_lastIssuanceId - 1);
        for (uint256 i = 1; i < _lastIssuanceId; i++) {
            issuanceAddresses[i - 1] = _issuanceProxies[i];
        }
        return issuanceAddresses;
    }


    /**
     * @dev Instrument type-specific issuance creation processing.
     * @param issuanceId ID of the issuance.
     * @param makerParameters The custom parameters to the newly created issuance
     * @param issuanceParametersData Issuance Parameters.
     */
    function _processCreateIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory makerParameters) internal
        returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        // Create an AdminOnlyUpgradeabilityProxy for the new issuance
        // Current Instrument Manager is the proxy admin for this proxy, and only the current
        // Instrument Manager can call fallback on the proxy.
        _issuanceProxies[issuanceId] = address(new AdminOnlyUpgradeabilityProxy(_instrumentAddress, address(this)));

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).createIssuance(issuanceParametersData, makerParameters);
    }

    /**
     * @dev Instrument type-specific issuance engage processing.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param takerParameters The custom parameters to the new engagement
     */
    function _processEngageIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory takerParameters) internal
        returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).engageIssuance(issuanceParametersData, takerParameters);
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

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).processTokenDeposit(
            issuanceParametersData, tokenAddress, amount);
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

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).processTokenWithdraw(
            issuanceParametersData, tokenAddress, amount);
    }

    /**
     * @dev Instrument type-specific custom event processing.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     */
    function _processCustomEvent(uint256 issuanceId, bytes memory issuanceParametersData, bytes32 eventName, bytes memory eventPayload)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        (updatedState, transfersData) = InstrumentV3(_issuanceProxies[issuanceId]).processCustomEvent(
            issuanceParametersData, eventName, eventPayload);
    }
}