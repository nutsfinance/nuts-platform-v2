pragma solidity ^0.5.0;

import "./InstrumentManagerInterface.sol";
import "./InstrumentBase.sol";
import "../InstrumentConfig.sol";
import "../escrow/InstrumentEscrowInterface.sol";
import "../escrow/IssuanceEscrowInterface.sol";
import "../escrow/DepositEscrowInterface.sol";
import "../escrow/EscrowFactoryInterface.sol";
import "../lib/token/SafeERC20.sol";
import "../lib/protobuf/InstrumentData.sol";
import "../lib/protobuf/TokenTransfer.sol";
import "../lib/util/Constants.sol";

/**
 * Base instrument manager for instrument v1, v2 and v3.
 */
contract InstrumentManagerBase is InstrumentManagerInterface {

    using SafeERC20 for IERC20;

    /**
     * @dev Common property of issuance.
     */
    struct IssuanceProperty {
        // Address of issuance creator
        address makerAddress;
        // When the issuance is created
        uint256 creationTimestamp;
        // Address of issuance taker
        address takerAddress;
        // When the issuance is engaged
        uint256 engagementTimestamp;
        // Amount of NUTS token deposited in creating this issuance
        uint256 deposit;
        // Address of Issuance Escrow
        address escrowAddress;
        // Current state of the issuance
        InstrumentBase.IssuanceStates state;
    }

    // Instrument expiration
    bool internal _active;
    uint256 internal _expiration;
    uint256 internal _startTimestamp;

    // Maker whitelist
    bool internal _makerWhitelistEnabled;
    mapping(address => bool) internal _makerWhitelist;

    // Taker whitelist
    bool internal _takerWhitelistEnabled;
    mapping(address => bool) internal _takerWhitelist;

    address internal _fspAddress;
    address internal _brokerAddress;
    address internal _instrumentAddress;
    uint256 internal _lastIssuanceId;
    // Amount of NUTS token deposited in creating this Instrument Manager.
    // As instrument deposit might change over time, Instrument Manager should remember the amount
    // of NUTS token deposited.
    uint256 internal _depositAmount;
    InstrumentConfig internal _instrumentConfig;
    // Instrument Escrow is singleton per each Instrument Manager.
    InstrumentEscrowInterface internal _instrumentEscrow;
    // We can derive the list of issuance id as [1, 2, 3, ..., _lastIssuanceId - 1]
    // so we don't need a separate array to store the issuance id list.
    mapping(uint256 => IssuanceProperty) internal _issuanceProperties;

    /**
     * @param fspAddress Address of FSP that activates this financial instrument.
     * @param instrumentAddress Address of the financial instrument contract.
     * @param instrumentConfigAddress Address of the Instrument Config contract.
     * @param instrumentParameters Custom parameters for the Instrument Manager.
     */
    constructor(address fspAddress, address instrumentAddress, address instrumentConfigAddress, bytes memory instrumentParameters) public {
        require(_instrumentAddress == address(0x0), "Already initialized");
        require(fspAddress != address(0x0), "FSP not set");
        require(instrumentAddress != address(0x0), "Instrument not set");
        require(instrumentConfigAddress != address(0x0), "Instrument config not set");
        require(instrumentParameters.length > 0, "Instrument parameters not set");

        InstrumentParameters.Data memory parameters = InstrumentParameters.decode(instrumentParameters);
        _active = true;
        _expiration = parameters.expiration;
        _startTimestamp = now;
        _makerWhitelistEnabled = parameters.supportMakerWhitelist;
        _takerWhitelistEnabled = parameters.supportTakerWhitelist;
        _instrumentConfig = InstrumentConfig(instrumentConfigAddress);

        _fspAddress = fspAddress;
        // If broker address is not provided, default to fsp address.
        _brokerAddress = parameters.brokerAddress == address(0x0) ? fspAddress : parameters.brokerAddress;
        _instrumentAddress = instrumentAddress;
        _lastIssuanceId = 1;
        // Deposit amount for Instrument activation might change. Need to record the amount deposited.
        _depositAmount = _instrumentConfig.instrumentDeposit();

        // Create Instrument Escrow
        _instrumentEscrow = EscrowFactoryInterface(_instrumentConfig.escrowFactoryAddress())
            .createInstrumentEscrow();
    }

    /**
     * @dev Get the Instrument Escrow.
     */
    function getInstrumentEscrowAddress() public view returns (address) {
        return address(_instrumentEscrow);
    }

    /**
     * @dev Get the current state of the issuance.
     */
    function getIssuanceState(uint256 issuanceId) public view returns (InstrumentBase.IssuanceStates) {
        return _issuanceProperties[issuanceId].state;
    }

    /**
     * @dev Deactivates the instrument.
     */
    function deactivate() public {
        require(_active, "Instrument deactivated");
        require(msg.sender == _fspAddress, "Only FSP can deactivate");

        // Return the deposited NUTS token
        if (_depositAmount > 0) {
            // Withdraw NUTS token from Deposit Escrow
            DepositEscrowInterface depositEscrow = DepositEscrowInterface(_instrumentConfig.depositEscrowAddress());
            depositEscrow.withdrawToken(_instrumentConfig.depositTokenAddress(), _depositAmount);

            // Transfer to FSP
            IERC20(_instrumentConfig.depositTokenAddress()).safeTransfer(_fspAddress, _depositAmount);
        }

        _active = false;
    }

    /**
     * @dev Updates the maker whitelist. The maker whitelist only affects new issuances.
     * @param makerAddress The maker address to update in whitelist
     * @param allowed Whether this maker is allowed to create new issuance.
     */
    function setMakerWhitelist(address makerAddress, bool allowed) public {
        require(_makerWhitelistEnabled, "Maker whitelist disabled");
        require(msg.sender == _fspAddress, "Only FSP can whitelist maker");

        _makerWhitelist[makerAddress] = allowed;
    }

    /**
     * @dev Updates the taker whitelist. The taker whitelist only affects new engagement.
     * @param takerAddress The taker address to update in whitelist
     * @param allowed Whether this taker is allowed to engage issuance.
     */
    function setTakerWhitelist(address takerAddress, bool allowed) public {
        require(_takerWhitelistEnabled, "Taker whitelist disabled");
        require(msg.sender == _fspAddress, "Only FSP can whitelist taker");

        _takerWhitelist[takerAddress] = allowed;
    }

    /**
     * @dev Create a new issuance of the financial instrument
     * @param makerParameters The custom parameters to the newly created issuance
     * @return The id of the newly created issuance.
     */
    function createIssuance(bytes memory makerParameters) public returns (uint256) {
        // The instrument is active if:
        // 1. It's not deactivated by FSP;
        // 2. It does not expiration, or expiration is not reached.
        require(_active && (_expiration == 0 || _expiration + _startTimestamp > now), "Instrument deactivated");
        // Maker is allowed if:
        // 1. Maker whitelist is not enabled;
        // 2. Or maker whitelist is enabled, and this maker is allowed.
        require(!_makerWhitelistEnabled || _makerWhitelist[msg.sender], "Maker not eligible");

        // Deposit NUTS token
        if (_instrumentConfig.issuanceDeposit() > 0) {
            // Withdraw NUTS token from Instrument Escrow
            _instrumentEscrow.withdrawTokenByAdmin(msg.sender, _instrumentConfig.depositTokenAddress(), _instrumentConfig.issuanceDeposit());
            // Deposit NUTS token to Deposit Escrow
            IERC20(_instrumentConfig.depositTokenAddress()).safeApprove(_instrumentConfig.depositEscrowAddress(), _instrumentConfig.issuanceDeposit());
            // Note: The owner of Deposit Escrow is Instrument Registry, not Instrument Manager!
            DepositEscrowInterface(_instrumentConfig.depositEscrowAddress())
                .depositToken(_instrumentConfig.depositTokenAddress(), _instrumentConfig.issuanceDeposit());
        }

        // Get issuance Id
        uint256 issuanceId = _lastIssuanceId;
        _lastIssuanceId++;

        // Create Issuance Escrow.
        IssuanceEscrowInterface issuanceEscrow = EscrowFactoryInterface(_instrumentConfig.escrowFactoryAddress())
            .createIssuanceEscrow();

        // Create Issuance Property
        _issuanceProperties[issuanceId] = IssuanceProperty({
            makerAddress: msg.sender,
            creationTimestamp: now,
            takerAddress: address(0x0),
            engagementTimestamp: 0,
            deposit: _instrumentConfig.issuanceDeposit(),
            escrowAddress: address(issuanceEscrow),
            state: InstrumentBase.IssuanceStates.Initiated
        });

        // Invoke Instrument
        bytes memory issuanceParametersData = _getIssuanceParameters(issuanceId);
        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processCreateIssuance(issuanceId,
            issuanceParametersData, makerParameters);
        _postProcessing(issuanceId, state, transfersData);
    }

    /**
     * @dev A taker engages to the issuance
     * @param issuanceId The id of the issuance
     * @param takerParameters The custom parameters to the new engagement
     */
    function engageIssuance(uint256 issuanceId, bytes memory takerParameters) public {
        // Taker is allowed if:
        // 1. Taker whitelist is not enabled;
        // 2. Or taker whitelist is enabled, and this taker is allowed.
        require(!_takerWhitelistEnabled || _takerWhitelist[msg.sender], "Taker not eligible");
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.state == InstrumentBase.IssuanceStates.Engageable, "Issuance not engageable");
        require(property.makerAddress != address(0x0), "Issuance not exist");

        property.takerAddress = msg.sender;
        property.engagementTimestamp = now;

        // Invoke Instrument
        bytes memory issuanceParametersData = _getIssuanceParameters(issuanceId);
        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processEngageIssuance(issuanceId,
            issuanceParametersData, takerParameters);

        _postProcessing(issuanceId, state, transfersData);
    }

    /**
     * @dev The caller deposits token from Instrument Escrow into issuance.
     * @param issuanceId The id of the issuance
     * @param tokenAddress The address of the token. The address for ETH is Contants.getEthAddress().
     * @param amount The amount of ERC20 token transfered
     */
    function depositToIssuance(uint256 issuanceId, address tokenAddress, uint256 amount) public {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(amount > 0, "Amount not set");
        require(property.makerAddress != address(0x0), "Issuance not exist");
        require(!_isIssuanceTerminated(property.state), "Issuance terminated");

        Transfer.Data memory transfer = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: msg.sender,
            toAddress: msg.sender,
            tokenAddress: tokenAddress,
            amount: amount
        });
        _processTransfer(issuanceId, transfer);

        // Invoke Instrument
        bytes memory issuanceParametersData = _getIssuanceParameters(issuanceId);
        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processTokenDeposit(issuanceId,
            issuanceParametersData, tokenAddress, amount);

        _postProcessing(issuanceId, state, transfersData);
    }

    /**
     * @dev The caller withdraws tokens from Issuance Escrow to Instrument Escrow.
     * @param issuanceId The id of the issuance
     * @param tokenAddress The address of the token. The address for ETH is Contants.getEthAddress().
     * @param amount The amount of ERC20 token transfered
     */
    function withdrawFromIssuance(uint256 issuanceId, address tokenAddress, uint256 amount) public {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(amount > 0, "Amount not set");
        require(property.makerAddress != address(0x0), "Issuance not exist");
        require(!_isIssuanceTerminated(property.state), "Issuance terminated");

        Transfer.Data memory transfer = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: msg.sender,
            toAddress: msg.sender,
            tokenAddress: tokenAddress,
            amount: amount
        });
        _processTransfer(issuanceId, transfer);

        // Invoke Instrument
        bytes memory issuanceParametersData = _getIssuanceParameters(issuanceId);
        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processTokenWithdraw(issuanceId,
            issuanceParametersData, Constants.getEthAddress(), amount);

        _postProcessing(issuanceId, state, transfersData);
    }

    /**
     * @dev Notify custom events to issuance. This could be invoked by any caller.
     * @param issuanceId The id of the issuance
     * @param eventName Name of the custom event
     * @param eventPayload Payload of the custom event
     */
    function notifyCustomEvent(uint256 issuanceId, bytes32 eventName, bytes memory eventPayload) public {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.makerAddress != address(0x0), "Issuance not exist");
        require(!_isIssuanceTerminated(property.state), "Issuance terminated");

        // Invoke Instrument
        bytes memory issuanceParametersData = _getIssuanceParameters(issuanceId);
        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processCustomEvent(issuanceId,
            issuanceParametersData, eventName, eventPayload);

        _postProcessing(issuanceId, state, transfersData);
    }

    /**
     * @dev Determines whether the issuance is in termination states.
     */
    function _isIssuanceTerminated(InstrumentBase.IssuanceStates state) internal pure returns (bool) {
        return state == InstrumentBase.IssuanceStates.Unfunded ||
            state == InstrumentBase.IssuanceStates.Cancelled ||
            state == InstrumentBase.IssuanceStates.CompleteNotEngaged ||
            state == InstrumentBase.IssuanceStates.CompleteEngaged ||
            state == InstrumentBase.IssuanceStates.Delinquent;
    }

    /**
     * @dev Determines whether the target address can take part in a transfer action.
     * For one issuance, only the issuance maker, issuance taker and instrument broker can
     * deposit to or withdraw from the issuance.
     */
    function _isTransferAllowed(uint256 issuanceId, address fromAddress, address toAddress) internal view returns (bool) {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        return (property.makerAddress == fromAddress || property.takerAddress == fromAddress || _brokerAddress == fromAddress)
            && (property.makerAddress == toAddress || property.takerAddress == toAddress || _brokerAddress == toAddress);
    }

    /**
     * @dev Get issuance parameters passed to Instruments.
     */
    function _getIssuanceParameters(uint256 issuanceId) private view returns (bytes memory) {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.Data({
            issuanceId: issuanceId,
            fspAddress: _fspAddress,
            brokerAddress: _brokerAddress,
            makerAddress: property.makerAddress,
            creationTimestamp: property.creationTimestamp,
            takerAddress: property.takerAddress,
            engagementTimestamp: property.engagementTimestamp,
            state: uint8(property.state),
            instrumentEscrowAddress: address(_instrumentEscrow),
            issuanceEscrowAddress: property.escrowAddress,
            callerAddress: msg.sender,
            priceOracleAddress: _instrumentConfig.priceOracleAddress()
        });

        return IssuanceParameters.encode(issuanceParameters);
    }

    /**
     * @dev Process updated state and transfers after instrument invocation.
     */
    function _postProcessing(uint256 issuanceId, InstrumentBase.IssuanceStates state, bytes memory transfersData) internal {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        // Processes state update.
        property.state = state;
        if (_isIssuanceTerminated(state) && property.deposit > 0) {
            // Withdraws NUTS token
            DepositEscrowInterface(_instrumentConfig.depositEscrowAddress())
                .withdrawToken(_instrumentConfig.depositTokenAddress(), property.deposit);

            // Transfer NUTS token to maker
            IERC20(_instrumentConfig.depositTokenAddress()).safeTransfer(property.makerAddress, property.deposit);
        }

        // Processes transfers.
        Transfers.Data memory transfers = Transfers.decode(transfersData);
        for (uint256 i = 0; i < transfers.actions.length; i++) {
            _processTransfer(issuanceId, transfers.actions[i]);
        }
    }

    /**
     * @dev Process a single token transfer action.
     */
    function _processTransfer(uint256 issuanceId, Transfer.Data memory transfer) private {
        // The transfer can only come from issuance maker, issuance taker and instrument broker.
        require(_isTransferAllowed(issuanceId, transfer.fromAddress, transfer.toAddress), "Transfer not allowed");

        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        IssuanceEscrowInterface issuanceEscrow = IssuanceEscrowInterface(property.escrowAddress);
        // Check whether it's outbound, inbound, or transfer within the escrow.
        if (transfer.outbound) {
            if (transfer.tokenAddress == Constants.getEthAddress()) {
                // First withdraw ETH from Issuance Escrow to owner
                issuanceEscrow.withdrawByAdmin(transfer.fromAddress, transfer.amount);
                // Then deposit the ETH from owner to Instrument Escrow
                _instrumentEscrow.depositByAdmin.value(transfer.amount)(transfer.toAddress);
            } else {
                // First withdraw ERC20 token from Issuance Escrow to owner
                issuanceEscrow.withdrawTokenByAdmin(transfer.fromAddress, transfer.tokenAddress, transfer.amount);
                // (Important!!!)Then set allowance for Instrument Escrow
                IERC20(transfer.tokenAddress).safeApprove(address(_instrumentEscrow), transfer.amount);
                // Then deposit the ERC20 token from owner to Instrument Escrow
                _instrumentEscrow.depositTokenByAdmin(transfer.toAddress, transfer.tokenAddress, transfer.amount);
            }
        } else if (transfer.inbound) {
            if (transfer.tokenAddress == Constants.getEthAddress()) {
                // First withdraw ETH from Instrument Escrow
                _instrumentEscrow.withdrawByAdmin(msg.sender, transfer.amount);
                // Then deposit ETH to Issuance Escrow
                IssuanceEscrowInterface(property.escrowAddress).depositByAdmin.value(transfer.amount)(msg.sender);
            } else {
                // Withdraw ERC20 token from Instrument Escrow
                _instrumentEscrow.withdrawTokenByAdmin(msg.sender, transfer.tokenAddress, transfer.amount);
                // IMPORTANT: Set allowance before deposit
                IERC20(transfer.tokenAddress).safeApprove(property.escrowAddress, transfer.amount);
                // Deposit ERC20 token to Issuance Escrow
                IssuanceEscrowInterface(property.escrowAddress).depositTokenByAdmin(msg.sender, transfer.tokenAddress, transfer.amount);
            }
        } else {
            // It's a transfer inside the issuance escrow
            if (transfer.tokenAddress == Constants.getEthAddress()) {
                issuanceEscrow.transfer(transfer.fromAddress, transfer.toAddress, transfer.amount);
            } else {
                issuanceEscrow.transferToken(transfer.fromAddress, transfer.toAddress, transfer.tokenAddress, transfer.amount);
            }
        }
    }

    /****************************************************************
     * Hook methods for Instrument type-specific implementations.
     ***************************************************************/

    /**
     * @dev Instrument type-specific issuance creation processing.
     */
    function _processCreateIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory makerParametersData) internal
        returns (InstrumentBase.IssuanceStates, bytes memory);

    /**
     * @dev Instrument type-specific issuance engage processing.
     */
    function _processEngageIssuance(uint256 issuanceId, bytes memory issuanceParametersData, bytes memory takerParameters) internal
        returns (InstrumentBase.IssuanceStates, bytes memory);

    /**
     * @dev Instrument type-specific issuance ERC20 token deposit processing.
     * Note: This method is called after deposit is complete, so that the Escrow reflects the balance after deposit.
     */
    function _processTokenDeposit(uint256 issuanceId, bytes memory issuanceParametersData, address tokenAddress, uint256 amount) internal
        returns (InstrumentBase.IssuanceStates, bytes memory);

    /**
     * @dev Instrument type-specific issuance ERC20 withdraw processing.
     * Note: This method is called after withdraw is complete, so that the Escrow reflects the balance after withdraw.
     */
    function _processTokenWithdraw(uint256 issuanceId, bytes memory issuanceParametersData, address tokenAddress, uint256 amount) internal
        returns (InstrumentBase.IssuanceStates, bytes memory);

    /**
     * @dev Instrument type-specific custom event processing.
     */
    function _processCustomEvent(uint256 issuanceId, bytes memory issuanceParametersData, bytes32 eventName,
        bytes memory eventPayload) internal returns (InstrumentBase.IssuanceStates, bytes memory);

}
