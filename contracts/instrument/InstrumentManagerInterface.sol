pragma solidity ^0.5.0;

import "./InstrumentBase.sol";
import "../escrow/InstrumentEscrowInterface.sol";

/**
 * @title The interace of instrument manager.
 * It serves as the interface between Instrument Registry and detailed implementation
 * of Instrument Manager on each version.
 */
interface InstrumentManagerInterface {

    /**
     * @dev Get the address of Instrument Escrow.
     */
    function getInstrumentEscrowAddress() external view returns (address);

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
     * @dev The caller deposits token from Instrument Escrow into Issuance Escrow.
     * @param issuanceId The id of the issuance
     * @param tokenAddress The address of the token. The address for ETH is Contants.getEthAddress().
     * @param amount The amount of ERC20 token transfered
     */
    function depositToIssuance(uint256 issuanceId, address tokenAddress, uint256 amount) external;

    /**
     * @dev The caller withdraws tokens from Issuance Escrow to Instrument Escrow.
     * @param issuanceId The id of the issuance
     * @param tokenAddress The address of the token. The address for ETH is Contants.getEthAddress().
     * @param amount The amount of ERC20 token transfered
     */
    function withdrawFromIssuance(uint256 issuanceId, address tokenAddress, uint256 amount) external;

    /**
     * @dev Notify events to issuance. This could be either custom event or scheduled event. Anyone can call this method.
     * @param issuanceId The id of the issuance
     * @param eventName Name of the custom event
     * @param eventPayload Payload of the custom event
     */
    function notifyCustomEvent(uint256 issuanceId, bytes32 eventName, bytes calldata eventPayload) external;

    /**
     * @dev Get custom data about the issuance.
     * @param issuanceId The id of the issuance
     * @param dataName Name of the custom data
     */
    function getCustomData(uint256 issuanceId, bytes32 dataName) external view returns (bytes memory);
}