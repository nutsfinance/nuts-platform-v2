pragma solidity ~0.5.0;

import "../InstrumentBase.sol";
import "../../escrow/EscrowBaseInterface.sol";
import "../../storage/StorageInterface.sol";

/**
 * @title Instrument v2 base contract.
 * A storage contract is created for each issuance.
 */
contract InstrumentV2 is InstrumentBase {
       /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceId The id of the issuance
     * @param makerAddress The address of the maker who creates this issuance
     * @param makerParameters The custom parameters to the newly created issuance
     * @param issuanceStorage The storage contract for this issuance.
     * @return updatedState The new state of the issuance.
     */
    function createIssuance(uint256 issuanceId, address makerAddress, bytes memory makerParameters, StorageInterface issuanceStorage)
        public returns (IssuanceStates updatedState);

    /**
     * @dev A taker engages to the issuance
     * @param issuanceId The id of the issuance
     * @param takerAddress The address of the taker who engages in the issuance
     * @param takerParameters The custom parameters to the new engagement
     * @param issuanceStorage The storage contract for this issuance.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(uint256 issuanceId, address takerAddress, bytes memory takerParameters,
        StorageInterface issuanceStorage, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev An account has made an ETH deposit to the issuance
     * @param issuanceId The id of the issuance
     * @param fromAddress The address of the ETH sender.
     * @param amount The amount of ETH deposited.
     * @param issuanceStorage The storage contract for this issuance.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processDeposit(uint256 issuanceId, address fromAddress, uint256 amount,
        StorageInterface issuanceStorage, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     * @param issuanceId The id of the issuance
     * @param fromAddress The address of the ERC20 token sender.
     * @param tokenAddress The address of the ERC20 token deposited.
     * @param amount The amount of ERC20 token deposited.
     * @param issuanceStorage The storage contract for this issuance.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(uint256 issuanceId, address fromAddress, address tokenAddress, uint256 amount,
        StorageInterface issuanceStorage, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);


    /**
     * @dev An account has made an ETH withdraw from the issuance
     * @param issuanceId The id of the issuance
     * @param toAddress The address of the ETH withdrawer.
     * @param amount The amount of ETH withdrawn.
     * @param issuanceStorage The storage contract for this issuance.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processWithdraw(uint256 issuanceId, address toAddress, uint256 amount,
        StorageInterface issuanceStorage, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     * @param issuanceId The id of the issuance
     * @param toAddress The address of the ERC20 token withdrawer.
     * @param tokenAddress The address of the ERC20 token withdrawn.
     * @param amount The amount of ERC20 token withdrawn.
     * @param issuanceStorage The storage contract for this issuance.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenWithdraw(uint256 issuanceId, address toAddress, address tokenAddress, uint256 amount,
        StorageInterface issuanceStorage, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev A custom event is triggered.
     * @param issuanceId The id of the issuance
     * @param notifierAddress The address of the caller who notifies the custom event.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @param issuanceStorage The storage contract for this issuance.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload,
        StorageInterface issuanceStorage, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

    /**
     * @dev A scheduled event is triggered.
     * @param issuanceId The id of the issuance
     * @param notifierAddress The address of the caller who notifies the scheduled event.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @param issuanceStorage The storage contract for this issuance.
     * @param state The current state of the issuance
     * @param escrow The Issuance Escrow of the issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processScheduledEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload,
        StorageInterface issuanceStorage, IssuanceStates state, EscrowBaseInterface escrow)
        public returns (IssuanceStates updatedState, bytes memory transfersData);

}