pragma solidity ^0.5.0;

/**
 * @title The interace of instrument manager.
 * It serves as the interface between Instrument Registry and detailed implementation
 * of Instrument Manager on each version.
 */
interface InstrumentManagerInterface {

    /**
     * @dev Deactivates the instrument.
     */
    function deactivate() external;

    /**
     * @dev Updates the maker whitelist. The maker whitelist only affects new issuances.
     * @param makerAddress The maker address to update in whitelist
     * @param allowed Whether this maker is allowed to create new issuance.
     */
    function setMakerWhitelist(address makerAddress, bool allowed) external;

    /**
     * @dev Updates the taker whitelist. The taker whitelist only affects new engagement.
     * @param takerAddress The taker address to update in whitelist
     * @param allowed Whether this taker is allowed to engage issuance.
     */
    function setTakerWhitelist(address takerAddress, bool allowed) external;

    /**
     * @dev Create a new issuance of the financial instrument
     * @param sellerParameters The custom parameters to the newly created issuance
     * @return The id of the newly created issuance.
     */
    function createIssuance(bytes calldata sellerParameters) external returns (uint256);

    /**
     * @dev A buyer engages to the issuance
     * @param issuanceId The id of the issuance
     * @param buyerParameters The custom parameters to the new engagement
     */
    function engageIssuance(uint256 issuanceId, bytes calldata buyerParameters) external;

    /**
     * @dev The caller attempts to complete one settlement.
     * @param issuanceId The id of the issuance
     * @param settlerParameters The custom parameters to the settlement
     */
    function settleIssuance(uint256 issuanceId, bytes calldata settlerParameters) external;

    /**
     * @dev The caller deposits ETH, which is currently deposited in Instrument Escrow, into issuance.
     * @param issuanceId The id of the issuance
     * @param amount The amount of ERC20 token transfered
     */
    function depositToIssuance(uint256 issuanceId, uint256 amount) external;

    /**
     * @dev The caller deposits ERC20 token, which is currently deposited in Instrument Escrow, into issuance.
     * @param issuanceId The id of the issuance
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     */
    function depositTokenToIssuance(uint256 issuanceId, address tokenAddress, uint256 amount) external;

    /**
     * @dev The caller withdraws ETH from issuance to Instrument Escrow.
     * @param issuanceId The id of the issuance
     * @param amount The amount of ERC20 token transfered
     */
    function withdrawFromIssuance(uint256 issuanceId, uint256 amount) external;

    /**
     * @dev The caller withdraws ERC20 token from issuance to Instrument Escrow.
     * @param issuanceId The id of the issuance
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     */
    function withdrawTokenFromIssuance(uint256 issuanceId, address tokenAddress, uint256 amount) external;

    /**
     * @dev Notify custom events to issuance. This could be invoked by any caller.
     * @param issuanceId The id of the issuance
     * @param eventName Name of the custom event
     * @param eventPayload Payload of the custom event
     */
    function notifyCustomEvent(uint256 issuanceId, string calldata eventName, bytes calldata eventPayload) external;

    /**
     * @dev Notify scheduled events to issuance. This could be invoked by Timer Oracle only.
     * @param issuanceId The id of the issuance
     * @param eventName Name of the scheduled event, eventName of EventScheduled event
     * @param eventPayload Payload of the scheduled event, eventPayload of EventScheduled event
     */
    function notifyScheduledEvent(uint256 issuanceId, string calldata eventName, bytes calldata eventPayload) external;
}