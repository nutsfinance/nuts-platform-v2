pragma solidity ^0.5.0;

import "../Instrument.sol";
import "./InstrumentV1.sol";
import "../InstrumentManagerInterface.sol";
import "../../escrow/EscrowInterface.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../lib/protobuf/InstrumentV1Data.sol";

contract InstrumentV1Manager is InstrumentManagerInterface {

    InstrumentV1 private _instrument;
    EscrowInterface private _escrow;
    address private _fspAddress;
    uint256 private _creationTimestamp;
    uint256 private _expirationTimestamp;
    mapping(uint256 => bytes) private _issuanceCommonProperties;
    mapping(uint256 => bytes) private _issuanceCustomProperties;

    constructor(InstrumentV1 instrument, EscrowInterface escrow, address fspAddress, bytes memory instrumentParameters) public {
        _instrument = instrument;
        _escrow = escrow;
        _fspAddress = fspAddress;
        _creationTimestamp = now;
        InstrumentParameters.Data memory parameters = InstrumentParameters.decode(instrumentParameters);
        _expirationTimestamp = now + parameters.expiration;
    }

    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceId The id of the issuance
     * @param sellerAddress The address of the seller who creates this issuance
     * @param sellerParameters The custom parameters to the newly created issuance
     * @return activeness The activeness of the issuance.
     */
    function createIssuance(uint256 issuanceId, address sellerAddress, bytes memory sellerParameters)
        public returns (IssuanceActiveness activeness) {
        require(issuanceId > 0, "InstrumentV1Manager: Issuance Id must be set.");
        require(sellerAddress != address(0x0), "InstrumentV1Manager: Seller address must be set.");
        // No new issuance is allowed when the instrument expires.
        require(_creationTimestamp == _expirationTimestamp || now <= _expirationTimestamp, "InstrumentV1Manager: Instrument expired.");
        require(_issuanceCommonProperties[issuanceId].length == 0, "InstrumentV1Manager: Issuance already exist.");

        IssuanceProperties.Data memory commonProperties = IssuanceProperties.Data(sellerAddress, now, 0);
        (Instrument.IssuanceStates updatedState, bytes memory updatedProperties,
            bytes memory transfers) = _instrument.createIssuance(issuanceId, sellerAddress, sellerParameters);

        return postProcessing(issuanceId, commonProperties, updatedState, updatedProperties, transfers);
    }

    /**
     * @dev A buyer engages to the issuance
     * @param issuanceId The id of the issuance
     * @param buyerAddress The address of the buyer who engages in the issuance
     * @param buyerParameters The custom parameters to the new engagement
     * @return activeness The activeness of the issuance.
     */
    function engageIssuance(uint256 issuanceId, address buyerAddress, bytes memory buyerParameters)
        public returns (IssuanceActiveness activeness) {
        require(issuanceId > 0, "InstrumentV1Manager: Issuance Id must be set.");
        require(buyerAddress != address(0x0), "InstrumentV1Manager: Buyer address must be set.");
        require(_issuanceCommonProperties[issuanceId].length > 0, "InstrumentV1Manager: Issuance does not exist.");
        IssuanceProperties.Data memory commonProperties = IssuanceProperties.decode(_issuanceCommonProperties[issuanceId]);
        bytes memory customProperties = _issuanceCustomProperties[issuanceId];
        bytes memory balances = _escrow.getIssuanceBalances(issuanceId);
        (Instrument.IssuanceStates updatedState, bytes memory updatedProperties,
            bytes memory transfers) = _instrument.engageIssuance(issuanceId, Instrument.IssuanceStates(commonProperties.state),
            customProperties, balances, buyerAddress, buyerParameters);
        
        return postProcessing(issuanceId, commonProperties, updatedState, updatedProperties, transfers);
    }

    /**
     * @dev The caller attempts to complete one settlement.
     * @param issuanceId The id of the issuance
     * @param settlerAddress The address of the buyer who settles in the issuance
     * @param settlerParameters The custom parameters to the settlement
     * @return activeness The activeness of the issuance.
     */
    function settleIssuance(uint256 issuanceId, address settlerAddress, bytes memory settlerParameters)
        public returns (IssuanceActiveness activeness) {
        require(issuanceId > 0, "InstrumentV1Manager: Issuance Id must be set.");
        require(settlerAddress != address(0x0), "InstrumentV1Manager: Settler address must be set.");
        require(_issuanceCommonProperties[issuanceId].length > 0, "InstrumentV1Manager: Issuance does not exist.");
        IssuanceProperties.Data memory commonProperties = IssuanceProperties.decode(_issuanceCommonProperties[issuanceId]);
        bytes memory customProperties = _issuanceCustomProperties[issuanceId];
        bytes memory balances = _escrow.getIssuanceBalances(issuanceId);
        (Instrument.IssuanceStates updatedState, bytes memory updatedProperties,
            bytes memory transfers) = _instrument.settleIssuance(issuanceId, Instrument.IssuanceStates(commonProperties.state),
            customProperties, balances, settlerAddress, settlerParameters);
        
        return postProcessing(issuanceId, commonProperties, updatedState, updatedProperties, transfers);
    }

    /**
     * @dev Buyer/Seller has made an ERC20 token deposit to the issuance
     * @param issuanceId The id of the issuance
     * @param fromAddress The address of the ERC20 token sender
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     * @return activeness The activeness of the issuance.
     */
    function processTokenDeposit(uint256 issuanceId, address fromAddress, address tokenAddress, uint256 amount)
        public returns (IssuanceActiveness activeness) {
        require(issuanceId > 0, "InstrumentV1Manager: Issuance Id must be set.");
        require(fromAddress != address(0x0), "InstrumentV1Manager: Sender address must be set.");
        require(tokenAddress != address(0x0), "InstrumentV1Manager: Token address must be set.");
        require(amount > 0, "InstrumentV1Manager: Transfer amount should be larger than zero.");
        require(_issuanceCommonProperties[issuanceId].length > 0, "InstrumentV1Manager: Issuance does not exist.");

        // Complete the token deposit first.
        processUserTransfer(issuanceId, fromAddress, tokenAddress, amount);

        IssuanceProperties.Data memory commonProperties = IssuanceProperties.decode(_issuanceCommonProperties[issuanceId]);
        bytes memory customProperties = _issuanceCustomProperties[issuanceId];
        // The balances show the state after transfering token to issuance.
        bytes memory balances = _escrow.getIssuanceBalances(issuanceId);
        (Instrument.IssuanceStates updatedState, bytes memory updatedProperties,
            bytes memory transfers) = _instrument.processTokenDeposit(issuanceId, Instrument.IssuanceStates(commonProperties.state),
            customProperties, balances, fromAddress, tokenAddress, amount);
        
        return postProcessing(issuanceId, commonProperties, updatedState, updatedProperties, transfers);
    }

    /**
     * @dev Buyer/Seller has made an ERC20 token withdraw from the issuance
     * @param issuanceId The id of the issuance
     * @param toAddress The address of the ERC20 token receiver
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     * @return activeness The activeness of the issuance.
     */
    function processTokenWithdraw(uint256 issuanceId, address toAddress, address tokenAddress, uint256 amount)
        public returns (IssuanceActiveness activeness) {
        require(issuanceId > 0, "InstrumentV1Manager: Issuance Id must be set.");
        require(toAddress != address(0x0), "InstrumentV1Manager: Receiver address must be set.");
        require(tokenAddress != address(0x0), "InstrumentV1Manager: Token address must be set.");
        require(amount > 0, "InstrumentV1Manager: Transfer amount should be larger than zero.");
        require(_issuanceCommonProperties[issuanceId].length > 0, "InstrumentV1Manager: Issuance does not exist.");

        // Complete the token deposit first.
        processUserTransfer(issuanceId, toAddress, tokenAddress, amount);

        IssuanceProperties.Data memory commonProperties = IssuanceProperties.decode(_issuanceCommonProperties[issuanceId]);
        bytes memory customProperties = _issuanceCustomProperties[issuanceId];
        // The balances show the state after transfering token from issuance.
        bytes memory balances = _escrow.getIssuanceBalances(issuanceId);
        (Instrument.IssuanceStates updatedState, bytes memory updatedProperties,
            bytes memory transfers) = _instrument.processTokenWithdraw(issuanceId, Instrument.IssuanceStates(commonProperties.state),
            customProperties, balances, toAddress, tokenAddress, amount);
        
        return postProcessing(issuanceId, commonProperties, updatedState, updatedProperties, transfers);
    }

    /**
     * @dev Process event. This event can be scheduled events or custom events.
     * @param issuanceId The id of the issuance
     * @param notifierAddress The address which notifies this scheduled event
     * @param eventName Name of the custom event, eventName of EventScheduled event
     * @param eventPayload Payload of the custom event, eventPayload of EventScheduled event
     * @return activeness The activeness of the issuance.
     */
    function processEvent(uint256 issuanceId, address notifierAddress, string memory eventName, bytes memory eventPayload)
        public returns (IssuanceActiveness activeness) {
        require(issuanceId > 0, "InstrumentV1Manager: Issuance Id must be set.");
        require(notifierAddress != address(0x0), "InstrumentV1Manager: Notifier address must be set.");
        require(bytes(eventName).length > 0, "InstrumentV1Manager: Event name must be set.");
        require(_issuanceCommonProperties[issuanceId].length > 0, "InstrumentV1Manager: Issuance does not exist.");
        IssuanceProperties.Data memory commonProperties = IssuanceProperties.decode(_issuanceCommonProperties[issuanceId]);
        bytes memory customProperties = _issuanceCustomProperties[issuanceId];
        bytes memory balances = _escrow.getIssuanceBalances(issuanceId);
        (Instrument.IssuanceStates updatedState, bytes memory updatedProperties,
            bytes memory transfers) = _instrument.processEvent(issuanceId, Instrument.IssuanceStates(commonProperties.state),
            customProperties, balances, notifierAddress, eventName, eventPayload);
        
        return postProcessing(issuanceId, commonProperties, updatedState, updatedProperties, transfers);
    }

    /**
     * @dev Complete the user transfer action. The transfer is from user to issuance.
     * @param issuanceId The destination issuance Id.
     * @param userAddress The source account address.
     * @param tokenAddress The address of the token transferred.
     * @param amount The amount to transfer.
     */
    function processUserTransfer(uint256 issuanceId, address userAddress, address tokenAddress, uint256 amount) private {
        Transfers.Data memory tokenDeposits = Transfers.Data(new Transfer.Data[](1));
        tokenDeposits.actions[0] = Transfer.Data({
            fromUser: false,
            issuanceId: issuanceId,
            userAddress: userAddress,
            tokenAddress: tokenAddress,
            amount: amount
        });
        _escrow.processTransfers(Transfers.encode(tokenDeposits));
    }

    /**
     * @dev Post processing after invoking instrument methods.
     */
    function postProcessing(uint256 issuanceId, IssuanceProperties.Data memory commonProperties, Instrument.IssuanceStates updatedState,
        bytes memory updatedProperties, bytes memory transfers) private returns (IssuanceActiveness activeness) {
        // Update and save common properties
        commonProperties.state = uint8(updatedState);
        _issuanceCommonProperties[issuanceId] = IssuanceProperties.encode(commonProperties);

        // Save the custom properties
        _issuanceCustomProperties[issuanceId] = updatedProperties;

        // Process the transfer actions
        _escrow.processTransfers(transfers);

        // Define the return value
        return _instrument.isTerminationState(updatedState) ? IssuanceActiveness.Inactive : IssuanceActiveness.Active;
    }
}