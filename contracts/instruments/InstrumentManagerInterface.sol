pragma solidity ^0.5.0;

/**
 * @title The interace of instrument manager.
 * It serves as the interface between Instrument Registry and detailed implementation
 * of Instrument Manager on each version.
 */
interface InstrumentManagerInterface {

    /**
     * The state of an issuance from Instrument Registry point of view.
     * The instrument can defined details lifecycle state, but Instrument Registry
     * only consider whether the issuance is active or not.
     * Once an issuance reaches the Inactive state, Instrument Registry will never
     * invoke this issuance.
     */
    enum IssuanceActiveness {
        Active,
        Inactive
    }

    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceId The id of the issuance
     * @param sellerAddress The address of the seller who creates this issuance
     * @param sellerParameters The custom parameters to the newly created issuance
     * @return activeness The activeness of the issuance.
     */
    function createIssuance(uint256 issuanceId, address sellerAddress, bytes calldata sellerParameters)
        external returns (IssuanceActiveness activeness);

    /**
     * @dev A buyer engages to the issuance
     * @param issuanceId The id of the issuance
     * @param buyerAddress The address of the buyer who engages in the issuance
     * @param buyerParameters The custom parameters to the new engagement
     * @return activeness The activeness of the issuance.
     */
    function engageIssuance(uint256 issuanceId, address buyerAddress, bytes calldata buyerParameters)
            external returns (IssuanceActiveness activeness);

    /**
     * @dev The caller attempts to complete one settlement.
     * @param issuanceId The id of the issuance
     * @param settlerAddress The address of the buyer who settles in the issuance
     * @param settlerParameters The custom parameters to the settlement
     * @return activeness The activeness of the issuance.
     */
    function settleIssuance(uint256 issuanceId, address settlerAddress, bytes calldata settlerParameters)
            external returns (IssuanceActiveness activeness);

    /**
     * @dev Buyer/Seller has made an ERC20 token deposit to the issuance
     * @param issuanceId The id of the issuance
     * @param fromAddress The address of the ERC20 token sender
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     * @return activeness The activeness of the issuance.
     */
    function processTokenDeposit(uint256 issuanceId, address fromAddress, address tokenAddress, uint256 amount)
            external returns (IssuanceActiveness activeness);

    /**
     * @dev Buyer/Seller has made an ERC20 token withdraw from the issuance
     * @param issuanceId The id of the issuance
     * @param toAddress The address of the ERC20 token receiver
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     * @return activeness The activeness of the issuance.
     */
    function processTokenWithdraw(uint256 issuanceId, address toAddress, address tokenAddress, uint256 amount)
            external returns (IssuanceActiveness activeness);

    /**
     * @dev Process event. This event can be scheduled events or custom events.
     * @param issuanceId The id of the issuance
     * @param notifierAddress The address which notifies this scheduled event
     * @param eventName Name of the custom event, eventName of EventScheduled event
     * @param eventPayload Payload of the custom event, eventPayload of EventScheduled event
     * @return activeness The activeness of the issuance.
     */
    function processEvent(uint256 issuanceId, address notifierAddress, string calldata eventName, bytes calldata eventPayload)
            external returns (IssuanceActiveness activeness);
}