pragma solidity ~0.5.0;

import "../Instrument.sol";
import "../../storage/StorageInterface.sol";

/**
 * @title Instrument v2 base contract.
 * A storage contract is created for each issuance.
 */
contract InstrumentV2 is Instrument {
    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceId The id of the issuance
     * @param issuanceStorage The storage contract of the issuance
     * @param sellerAddress The address of the seller who creates this issuance
     * @param sellerParameters The custom parameters to the newly created issuance
     * @return transfers The transfers to perform after the invocation
     */
    function createIssuance(uint256 issuanceId, StorageInterface issuanceStorage, address sellerAddress, bytes memory sellerParameters)
        public returns (IssuanceStates updatedState, bytes memory transfers);

    /**
     * @dev A buyer engages to the issuance
     * @param issuanceId The id of the issuance
     * @param state The current state of the issuance
     * @param issuanceStorage The storage contract of the issuance
     * @param balances The current balance of the issuance
     * @param buyerAddress The address of the buyer who engages in the issuance
     * @param buyerParameters The custom parameters to the new engagement
     * @return transfers The transfers to perform after the invocation
     */
    function engageIssuance(uint256 issuanceId, IssuanceStates state, StorageInterface issuanceStorage,
        bytes memory balances, address buyerAddress, bytes memory buyerParameters)
            public returns (IssuanceStates updatedState, bytes memory transfers);

    /**
     * @dev The caller attempts to complete one settlement.
     * @param issuanceId The id of the issuance
     * @param state The current state of the issuance
     * @param issuanceStorage The storage contract of the issuance
     * @param balances The current balance of the issuance
     * @param settlerAddress The address of the buyer who settles in the issuance
     * @param settlerParameters The custom parameters to the settlement
     * @return transfers The transfers to perform after the invocation
     */
    function settleIssuance(uint256 issuanceId, IssuanceStates state, StorageInterface issuanceStorage,
        bytes memory balances, address settlerAddress, bytes memory settlerParameters)
            public returns (IssuanceStates updatedState, bytes memory transfers);

    /**
     * @dev Buyer/Seller has made an ERC20 token deposit to the issuance
     * @param issuanceId The id of the issuance
     * @param state The current state of the issuance
     * @param issuanceStorage The storage contract of the issuance
     * @param balances The current balance of the issuance (after the deposit)
     * @param fromAddress The address of the ERC20 token sender
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     * @return updatedProperties The updated properties of the issuance.
     * @return transfers The transfers to perform after the invocation
     */
    function processTokenDeposit(uint256 issuanceId, IssuanceStates state, StorageInterface issuanceStorage,
        bytes memory balances, address fromAddress, address tokenAddress, uint256 amount)
            public returns (IssuanceStates updatedState, bytes memory transfers);

    /**
     * @dev Buyer/Seller has made an ERC20 token withdraw from the issuance
     * @param issuanceId The id of the issuance
     * @param state The current state of the issuance
     * @param issuanceStorage The storage contract of the issuance
     * @param balances The current balance of the issuance (after the withdraw)
     * @param toAddress The address of the ERC20 token receiver
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     * @return updatedProperties The updated properties of the issuance.
     * @return transfers The transfers to perform after the invocation
     */
    function processTokenWithdraw(uint256 issuanceId, IssuanceStates state, StorageInterface issuanceStorage,
        bytes memory balances, address toAddress, address tokenAddress, uint256 amount)
            public returns (IssuanceStates updatedState, bytes memory transfers);

    /**
     * @dev Process customer event
     * @param issuanceId The id of the issuance
     * @param state The current state of the issuance
     * @param issuanceStorage The storage contract of the issuance
     * @param balances The current balance of the issuance
     * @param notifierAddress The address which notifies this custom event
     * @param eventName Name of the custom event, eventName of EventScheduled event
     * @param eventPayload Payload of the custom event, eventPayload of EventScheduled event
     * @return updatedProperties The updated properties of the issuance.
     * @return transfers The transfers to perform after the invocation
     */
    function processEvent(uint256 issuanceId, IssuanceStates state, StorageInterface issuanceStorage,
        bytes memory balances, address notifierAddress, string memory eventName, bytes memory eventPayload)
            public returns (IssuanceStates updatedState, bytes memory transfers);
}