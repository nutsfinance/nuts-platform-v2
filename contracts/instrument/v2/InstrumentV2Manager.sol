pragma solidity ^0.5.0;

import "../../access/WriterRole.sol";
import "../../escrow/EscrowBaseInterface.sol";
import "../../storage/StorageInterface.sol";
import "../../storage/StorageFactoryInterface.sol";
import "../../InstrumentConfig.sol";
import "../InstrumentBase.sol";
import "../InstrumentManagerBase.sol";
import "./InstrumentV2.sol";

/**
 * @title Instrument Manager for Instrument v2.
 * A storage contract is created for each issuance.
 */
contract InstrumentV2Manager is InstrumentManagerBase {

    // Mapping: Issuance Id => Issuance storage contract address
    mapping(uint256 => address) private _issuanceStorages;
    StorageFactoryInterface private _storageFactory;

    /**
     * @param fspAddress Address of FSP that activates this financial instrument.
     * @param instrumentAddress Address of the financial instrument contract.
     * @param instrumentConfigAddress Address of the Instrument Config contract.
     * @param instrumentParameters Custom parameters for the Instrument Manager.
     * @param storageFactoryAddress Address of the storage factory.
     */
    constructor(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        bytes memory instrumentParameters, address storageFactoryAddress)
        InstrumentManagerBase(fspAddress, instrumentAddress, instrumentConfigAddress, instrumentParameters) public {
        _storageFactory = StorageFactoryInterface(storageFactoryAddress);
    }

    /**
     * @dev Instrument type-specific issuance creation processing.
     * @param issuanceId ID of the issuance.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @param issuanceParametersData Issuance Parameters.
     */
    function _processCreateIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory makerParametersData) internal
        returns (InstrumentBase.IssuanceStates updatedState) {

        // Create storage contract
        StorageInterface issuanceStorage = _storageFactory.createStorageInstance();
        _issuanceStorages[issuanceId] = address(issuanceStorage);

        // Temporary grant writer role
        issuanceStorage.addWriter(_instrumentAddress);

        updatedState = InstrumentV2(_instrumentAddress).createIssuance(issuanceParametersData, makerParametersData, issuanceStorage);

        // Revoke writer role
        issuanceStorage.removeWriter(_instrumentAddress);
    }

    /**
     * @dev Instrument type-specific issuance engage processing.
     * @param issuanceId ID of the issuance.
     * @param takerParameters The custom parameters to the new engagement
     * @param issuanceParametersData Issuance Parameters.
     */
    function _processEngageIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory takerParameters)
        internal returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        // Temporary grant writer role
        StorageInterface issuanceStorage = StorageInterface(_issuanceStorages[issuanceId]);
        issuanceStorage.addWriter(_instrumentAddress);

        (updatedState, transfersData) = InstrumentV2(_instrumentAddress).engageIssuance(issuanceParametersData,
            takerParameters, issuanceStorage);

        // Revoke writer role
        issuanceStorage.removeWriter(_instrumentAddress);
    }

    /**
     * @dev Instrument type-specific issuance ERC20 token deposit processing.
     * Note: This method is called after deposit is complete, so that the Escrow reflects the balance after deposit.
     * @param issuanceId ID of the issuance.
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     */
    function _processTokenDeposit(uint256 issuanceId, bytes memory issuanceParametersData, address tokenAddress, uint256 amount) internal
        returns (InstrumentBase.IssuanceStates updatedState, bytes memory transfersData) {

        // Temporary grant writer role
        StorageInterface issuanceStorage = StorageInterface(_issuanceStorages[issuanceId]);
        issuanceStorage.addWriter(_instrumentAddress);

        (updatedState, transfersData) = InstrumentV2(_instrumentAddress).processTokenDeposit(issuanceParametersData,
            tokenAddress, amount, issuanceStorage);

        // Revoke writer role
        issuanceStorage.removeWriter(_instrumentAddress);
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

        // Temporary grant writer role
        StorageInterface issuanceStorage = StorageInterface(_issuanceStorages[issuanceId]);
        issuanceStorage.addWriter(_instrumentAddress);

        (updatedState, transfersData) = InstrumentV2(_instrumentAddress).processTokenWithdraw(issuanceParametersData,
            tokenAddress, amount, issuanceStorage);

        // Revoke writer role
        issuanceStorage.removeWriter(_instrumentAddress);
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

        // Temporary grant writer role
        StorageInterface issuanceStorage = StorageInterface(_issuanceStorages[issuanceId]);
        issuanceStorage.addWriter(_instrumentAddress);

        (updatedState, transfersData) = InstrumentV2(_instrumentAddress).processCustomEvent(
            issuanceParametersData, eventName, eventPayload, issuanceStorage);

        // Revoke writer role
        issuanceStorage.removeWriter(_instrumentAddress);
    }
}