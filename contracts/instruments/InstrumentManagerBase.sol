pragma solidity ^0.5.0;

import "./InstrumentManagerInterface.sol";
import "./InstrumentBase.sol";
import "../InstrumentConfig.sol";
import "../access/TimerOracleRole.sol";
import "../escrow/InstrumentEscrow.sol";
import "../escrow/IssuanceEscrow.sol";
import "../escrow/DepositEscrow.sol";
import "../lib/token/IERC20.sol";
import "../lib/token/SafeERC20.sol";
import "../lib/protobuf/InstrumentData.sol";
import "../lib/protobuf/TokenTransfer.sol";
import "../lib/proxy/AdminUpgradeabilityProxy.sol";
import "../lib/util/Constants.sol";

/**
 * Base instrument manager for instrument v1, v2 and v3.
 */
contract InstrumentManagerBase is InstrumentManagerInterface, TimerOracleRole {
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
    address internal _instrumentConfigAddress;
    uint256 internal _lastIssuanceId;
    uint256 internal _depositAmount;
    InstrumentEscrow internal _instrumentEscrow;
    mapping(uint256 => IssuanceProperty) internal _issuanceProperties;

    /**
     * @dev IMPORTANT: Initialization method for all instrument managers.
     * This function must be invoked immediately after creating the proxy and updating implementation.
     * If it's invoked in a separate transaction, it's possible that it's already invoked by someone else.
     * @param fspAddress Address of FSP that activates this financial instrument.
     * @param instrumentAddress Address of the financial instrument contract.
     * @param instrumentConfigAddress Address of the Instrument Config contract.
     * @param instrumentParameters Custom parameters for the Instrument Manager.
     */
    function initialize(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        bytes memory instrumentParameters) public {
        require(_instrumentAddress == address(0x0), "InstrumentManagerBase: Already initialized.");
        require(fspAddress != address(0x0), "InstrumentManagerBase: FSP address must be provided.");
        require(instrumentAddress != address(0x0), "InstrumentManagerBase: Instrument address must be provided.");
        require(instrumentConfigAddress != address(0x0), "InstrumentManagerBase: Instrument Config address must be provided.");
        require(instrumentParameters.length > 0, "InstrumentManagerBase: Instrument parameters must be provided.");

        InstrumentParameters.Data memory parameters = InstrumentParameters.decode(instrumentParameters);
        _active = true;
        _expiration = parameters.expiration;
        _startTimestamp = now;
        _makerWhitelistEnabled = parameters.supportMakerWhitelist;
        _takerWhitelistEnabled = parameters.supportTakerWhitelist;

        // Set Timer Oracle Role
        _addTimerOracle(InstrumentConfig(_instrumentConfigAddress).timerOracleAddress());
        _fspAddress = fspAddress;
        // If broker address is not provided, default to fsp address.
        _brokerAddress = parameters.brokerAddress == address(0x0) ? fspAddress : parameters.brokerAddress;
        _instrumentAddress = instrumentAddress;
        _instrumentConfigAddress = instrumentConfigAddress;
        _lastIssuanceId = 1;
        _depositAmount = InstrumentConfig(_instrumentConfigAddress).instrumentDeposit();

        // Create Instrument Escrow
        InstrumentEscrow instrumentEscrow = new InstrumentEscrow();
        AdminUpgradeabilityProxy instrumentEscrowProxy = new AdminUpgradeabilityProxy(address(instrumentEscrow),
            InstrumentConfig(_instrumentConfigAddress).proxyAdminAddress(), new bytes(0));
        // The owner of Instrument Escrow is Instrument Manager
        IssuanceEscrow(address(instrumentEscrowProxy)).initialize(address(this));

        _instrumentEscrow = InstrumentEscrow(address(instrumentEscrowProxy));
    }

    /**
     * @dev Get the address of Instrument Escrow.
     */
    function getInstrumentEscrow() public returns (address) {
        return address(_instrumentEscrow);
    }

    /**
     * @dev Deactivates the instrument.
     */
    function deactivate() public {
        require(_active, "InstrumentManagerBase: The instrument is already deactivated.");
        require(msg.sender == _fspAddress, "InstrumentManagerBase: Only FSP can deactivate the instrument.");

        // Return the deposited NUTS token
        if (_depositAmount > 0) {
            // Withdraw NUTS token from Deposit Escrow
            InstrumentConfig config = InstrumentConfig(_instrumentConfigAddress);
            DepositEscrow depositEscrow = DepositEscrow(config.depositEscrowAddress());
            depositEscrow.withdrawToken(IERC20(config.depositTokenAddress()), _depositAmount);

            // Transfer to FSP
            IERC20(config.depositTokenAddress()).safeTransfer(_fspAddress, _depositAmount);
        }

        _active = false;
    }

    /**
     * @dev Updates the maker whitelist. The maker whitelist only affects new issuances.
     * @param makerAddress The maker address to update in whitelist
     * @param allowed Whether this maker is allowed to create new issuance.
     */
    function setMakerWhitelist(address makerAddress, bool allowed) public {
        require(_makerWhitelistEnabled, "InstrumentManagerBase: Maker whitelist is not enabled.");
        require(msg.sender == _fspAddress, "InstrumentManagerBase: Only FSP can update maker whitelist.");

        _makerWhitelist[makerAddress] = allowed;
    }

    /**
     * @dev Updates the taker whitelist. The taker whitelist only affects new engagement.
     * @param takerAddress The taker address to update in whitelist
     * @param allowed Whether this taker is allowed to engage issuance.
     */
    function setTakerWhitelist(address takerAddress, bool allowed) public {
        require(_takerWhitelistEnabled, "InstrumentManagerBase: Taker whitelist is not enabled.");
        require(msg.sender == _fspAddress, "InstrumentManagerBase: Only FSP can update taker whitelist.");

        _takerWhitelist[takerAddress] = allowed;
    }

    /**
     * @dev Create a new issuance of the financial instrument
     * @param makerParameters The custom parameters to the newly created issuance
     * @return The id of the newly created issuance.
     */
    function createIssuance(bytes memory makerParameters) public returns (uint256) {
        require(_isActive(), "InstrumentManagerBase: Instrument is deactivated.");
        require(_isMakerAllowed(msg.sender), "InstrumentManagerBase: Not an eligible maker.");

        // Deposit NUTS token
        InstrumentConfig config = InstrumentConfig(_instrumentConfigAddress);
        if (config.issuanceDeposit() > 0) {
            // Withdraw NUTS token from Instrument Escrow
            _instrumentEscrow.withdrawTokenByAdmin(msg.sender, config.depositTokenAddress(), config.issuanceDeposit());
            // Deposit NUTS token to Deposit Escrow
            IERC20(config.depositTokenAddress()).safeApprove(config.depositEscrowAddress(), config.issuanceDeposit());
            // Note: The owner of Deposit Escrow is Instrument Registry, not Instrument Manager!
            DepositEscrow(config.depositEscrowAddress()).depositToken(IERC20(config.depositTokenAddress()), config.issuanceDeposit());
        }

        // Invoke Instrument
        uint256 issuanceId = _lastIssuanceId;
        _lastIssuanceId++;
        InstrumentBase.IssuanceStates state = _processCreateIssuance(issuanceId, msg.sender, makerParameters);

        // Create Issuance Escrow
        IssuanceEscrow issuanceEscrow = new IssuanceEscrow();
        AdminUpgradeabilityProxy issuanceEscrowProxy = new AdminUpgradeabilityProxy(address(issuanceEscrow),
            config.proxyAdminAddress(), new bytes(0));
        IssuanceEscrow(address(issuanceEscrowProxy)).initialize(address(this));

        // Create Issuance Property
        IssuanceProperty memory property = IssuanceProperty({
            makerAddress: msg.sender,
            creationTimestamp: now,
            takerAddress: address(0x0),
            engagementTimestamp: 0,
            deposit: config.issuanceDeposit(),
            escrowAddress: address(issuanceEscrowProxy),
            state: state
        });
        _issuanceProperties[issuanceId] = property;
    }

    /**
     * @dev A taker engages to the issuance
     * @param issuanceId The id of the issuance
     * @param takerParameters The custom parameters to the new engagement
     */
    function engageIssuance(uint256 issuanceId, bytes memory takerParameters) public {
        require(_isTakerAllowed(msg.sender), "InstrumentManagerBase: Not an eligible taker.");
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.makerAddress != address(0x0), "InstrumentManagerBase: Issuance not exist.");
        require(!_isIssuanceTerminated(property.state), "InstrumentManagerBase: Issuance terminated.");

        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processEngageIssuance(issuanceId,
            msg.sender, takerParameters, property.state, EscrowBaseInterface(property.escrowAddress));

        property.state = state;
        if (_isIssuanceTerminated(state)) {
            _returnIssuanceDeposit(issuanceId);
        }
        _processTransfers(issuanceId, transfersData);
    }

    /**
     * @dev The caller deposits ETH, which is currently deposited in Instrument Escrow, into issuance.
     * @param issuanceId The id of the issuance
     * @param amount The amount of ERC20 token transfered
     */
    function depositToIssuance(uint256 issuanceId, uint256 amount) public {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.makerAddress != address(0x0), "InstrumentManagerBase: Issuance not exist.");
        require(!_isIssuanceTerminated(property.state), "InstrumentManagerBase: Issuance terminated.");
        require(amount > 0, "InstrumentManagerBase: Amount must be set.");
        // The deposit can only come from issuance maker, issuance taker and instrument broker.
        require(_isTransferAllowed(issuanceId, msg.sender), "InstrumentManagerBase: Deposit is not allowed.");

        // Withdraw ETH from Instrument Escrow
        _instrumentEscrow.withdrawByAdmin(msg.sender, amount);
        // Deposit ETH to Issuance Escrow
        IssuanceEscrow(property.escrowAddress).depositByAdmin.value(amount)(msg.sender);

        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processTokenDeposit(issuanceId,
            msg.sender, Constants.getEthAddress(), amount, property.state, EscrowBaseInterface(property.escrowAddress));

        property.state = state;
        if (_isIssuanceTerminated(state)) {
            _returnIssuanceDeposit(issuanceId);
        }
        _processTransfers(issuanceId, transfersData);
    }

    /**
     * @dev The caller deposits ERC20 token, which is currently deposited in Instrument Escrow, into issuance.
     * @param issuanceId The id of the issuance
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     */
    function depositTokenToIssuance(uint256 issuanceId, address tokenAddress, uint256 amount) public {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.makerAddress != address(0x0), "InstrumentManagerBase: Issuance not exist.");
        require(!_isIssuanceTerminated(property.state), "InstrumentManagerBase: Issuance terminated.");
        require(tokenAddress != address(0x0), "InstrumentManagerBase: Token address must be set.");
        require(amount > 0, "InstrumentManagerBase: Amount must be set.");
        // The deposit can only come from issuance maker, issuance taker and instrument broker.
        require(_isTransferAllowed(issuanceId, msg.sender), "InstrumentManagerBase: Deposit is not allowed.");

        // Withdraw ERC20 token from Instrument Escrow
        _instrumentEscrow.withdrawTokenByAdmin(msg.sender, tokenAddress, amount);
        // IMPORTANT: Set allowance before deposit
        IERC20(tokenAddress).safeApprove(property.escrowAddress, amount);
        // Deposit ERC20 token to Issuance Escrow
        IssuanceEscrow(property.escrowAddress).depositTokenByAdmin(msg.sender, tokenAddress, amount);

        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processTokenDeposit(issuanceId,
            msg.sender, tokenAddress, amount, property.state, EscrowBaseInterface(property.escrowAddress));

        property.state = state;
        if (_isIssuanceTerminated(state)) {
            _returnIssuanceDeposit(issuanceId);
        }
        _processTransfers(issuanceId, transfersData);
    }

    /**
     * @dev The caller withdraws ETH from issuance to Instrument Escrow.
     * @param issuanceId The id of the issuance
     * @param amount The amount of ERC20 token transfered
     */
    function withdrawFromIssuance(uint256 issuanceId, uint256 amount) public {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.makerAddress != address(0x0), "InstrumentManagerBase: Issuance not exist.");
        require(!_isIssuanceTerminated(property.state), "InstrumentManagerBase: Issuance terminated.");
        require(amount > 0, "InstrumentManagerBase: Amount must be set.");
        // The withdraw can only come from issuance maker, issuance taker and instrument broker.
        require(_isTransferAllowed(issuanceId, msg.sender), "InstrumentManagerBase: Withdrawal is not allowed.");

        // Withdraw ETH from Issuance Escrow
        IssuanceEscrow(property.escrowAddress).withdrawByAdmin(msg.sender, amount);
        // Deposit ETH to Instrument Escrow
        _instrumentEscrow.depositByAdmin.value(amount)(msg.sender);

        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processTokenWithdraw(issuanceId,
            msg.sender, Constants.getEthAddress(), amount, property.state, EscrowBaseInterface(property.escrowAddress));

        property.state = state;
        if (_isIssuanceTerminated(state)) {
            _returnIssuanceDeposit(issuanceId);
        }
        _processTransfers(issuanceId, transfersData);
    }

    /**
     * @dev The caller withdraws ERC20 token from issuance to Instrument Escrow.
     * @param issuanceId The id of the issuance
     * @param tokenAddress The address of the ERC20 token
     * @param amount The amount of ERC20 token transfered
     */
    function withdrawTokenFromIssuance(uint256 issuanceId, address tokenAddress, uint256 amount) public {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.makerAddress != address(0x0), "InstrumentManagerBase: Issuance not exist.");
        require(!_isIssuanceTerminated(property.state), "InstrumentManagerBase: Issuance terminated.");
        require(tokenAddress != address(0x0), "InstrumentManagerBase: Token address must be set.");
        require(amount > 0, "InstrumentManagerBase: Amount must be set.");
        // The withdraw can only come from issuance maker, issuance taker and instrument broker.
        require(_isTransferAllowed(issuanceId, msg.sender), "InstrumentManagerBase: Withdrawal is not allowed.");

        // Withdraw ERC20 token from Issuance Escrow
        IssuanceEscrow(property.escrowAddress).withdrawTokenByAdmin(msg.sender, tokenAddress, amount);
        // IMPORTANT: Set allowance before deposit
        IERC20(tokenAddress).safeApprove(address(_instrumentEscrow), amount);
        // Deposit ERC20 token to Instrument Escrow
        _instrumentEscrow.depositTokenByAdmin(msg.sender, tokenAddress, amount);

        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processTokenWithdraw(issuanceId,
            msg.sender, tokenAddress, amount, property.state, EscrowBaseInterface(property.escrowAddress));

        property.state = state;
        if (_isIssuanceTerminated(state)) {
            _returnIssuanceDeposit(issuanceId);
        }
        _processTransfers(issuanceId, transfersData);
    }

    /**
     * @dev Notify custom events to issuance. This could be invoked by any caller.
     * @param issuanceId The id of the issuance
     * @param eventName Name of the custom event
     * @param eventPayload Payload of the custom event
     */
    function notifyCustomEvent(uint256 issuanceId, string memory eventName, bytes memory eventPayload) public {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.makerAddress != address(0x0), "InstrumentManagerBase: Issuance not exist.");
        require(!_isIssuanceTerminated(property.state), "InstrumentManagerBase: Issuance terminated.");
        require(bytes(eventName).length > 0, "InstrumentManagerBase: Event name must be provided.");

        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processCustomEvent(issuanceId,
            msg.sender, eventName, eventPayload, property.state, EscrowBaseInterface(property.escrowAddress));

        property.state = state;
        if (_isIssuanceTerminated(state)) {
            _returnIssuanceDeposit(issuanceId);
        }
        _processTransfers(issuanceId, transfersData);
    }

    /**
     * @dev Notify scheduled events to issuance. This could be invoked by Timer Oracle only.
     * Only the address with Timer Oracle Role can invoke notify scheduled event.
     * @param issuanceId The id of the issuance
     * @param eventName Name of the scheduled event, eventName of EventScheduled event
     * @param eventPayload Payload of the scheduled event, eventPayload of EventScheduled event
     */
    function notifyScheduledEvent(uint256 issuanceId, string memory eventName, bytes memory eventPayload) public onlyTimerOracle {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        require(property.makerAddress != address(0x0), "InstrumentManagerBase: Issuance not exist.");
        require(!_isIssuanceTerminated(property.state), "InstrumentManagerBase: Issuance terminated.");
        require(bytes(eventName).length > 0, "InstrumentManagerBase: Event name must be provided.");

        (InstrumentBase.IssuanceStates state, bytes memory transfersData) = _processScheduledEvent(issuanceId,
            msg.sender, eventName, eventPayload, property.state, EscrowBaseInterface(property.escrowAddress));

        property.state = state;
        if (_isIssuanceTerminated(state)) {
            _returnIssuanceDeposit(issuanceId);
        }
        _processTransfers(issuanceId, transfersData);
    }

    /**
     * @dev Validate whether the instrumment is active.
     */
    function _isActive() internal view returns (bool) {
        // The instrument is active if:
        // 1. It's not deactivated by FSP;
        // 2. It does not expiration, or expiration is not reached.
        return _active && (_expiration == 0 || _expiration + _startTimestamp > now);
    }

    /**
     * @dev Validate whether the maker can create new issuance.
     */
    function _isMakerAllowed(address makerAddress) internal view returns (bool) {
        // Maker is allowed if:
        // 1. Maker whitelist is not enabled;
        // 2. Or maker whitelist is enabled, and this maker is allowed.
        return !_makerWhitelistEnabled || _makerWhitelist[makerAddress];
    }

    /**
     * @dev Validate whether the taker can engage existing issuance.
     */
    function _isTakerAllowed(address takerAddress) internal view returns (bool) {
        // Taker is allowed if:
        // 1. Taker whitelist is not enabled;
        // 2. Or taker whitelist is enabled, and this taker is allowed.
        return !_takerWhitelistEnabled || _takerWhitelist[takerAddress];
    }

    /**
     * @dev Determines whether the issuance is in termination states.
     */
    function _isIssuanceTerminated(InstrumentBase.IssuanceStates state) internal pure returns (bool) {
        return state == InstrumentBase.IssuanceStates.Unfunded ||
            state == InstrumentBase.IssuanceStates.CompleteNotEngaged ||
            state == InstrumentBase.IssuanceStates.CompleteEngaged ||
            state == InstrumentBase.IssuanceStates.Delinquent;
    }

    /**
     * @dev Determines whether the target address can take part in a transfer action.
     * For one issuance, only the issuance maker, issuance taker and instrument broker can
     * deposit to or withdraw from the issuance.
     */
    function _isTransferAllowed(uint256 issuanceId, address targetAddress) internal view returns (bool) {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        return property.makerAddress == targetAddress || property.takerAddress == targetAddress
            || _brokerAddress == targetAddress;
    }

    /**
     * @dev Return the deposited NUTS token to the maker.
     */
    function _returnIssuanceDeposit(uint256 issuanceId) internal {
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        if (property.deposit > 0) {
            // Withdraws NUTS token
            InstrumentConfig config = InstrumentConfig(_instrumentConfigAddress);
            DepositEscrow(config.depositEscrowAddress()).withdrawToken(IERC20(config.depositTokenAddress()), property.deposit);

            // Transfer NUTS token to maker
            IERC20(config.depositTokenAddress()).safeTransfer(property.makerAddress, property.deposit);
        }
    }

    /**
     * @dev Process the transfers triggered by Instrumetns.
     */
    function _processTransfers(uint256 issuanceId, bytes memory transfersData) internal {
        Transfers.Data memory transfers = Transfers.decode(transfersData);
        IssuanceProperty storage property = _issuanceProperties[issuanceId];
        IssuanceEscrow issuanceEscrow = IssuanceEscrow(property.escrowAddress);
        for (uint256 i = 0; i < transfers.actions.length; i++) {
            Transfer.Data memory transfer = transfers.actions[i];
            // The transfer can only come from issuance maker, issuance taker and instrument broker.
            require(_isTransferAllowed(issuanceId, transfer.fromAddress), "InstrumentManagerBase: Transfer source is not allowed.");
            // The transfer can only send to issuance maker, issuance taker and instrument broker.
            require(_isTransferAllowed(issuanceId, transfer.toAddress), "InstrumentManagerBase: Transfer target is not allowed.");
            // Check wether it's an outbound transfer
            if (transfer.isOutbound) {
                if (transfer.isEther) {
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
            } else {
                // It's a transfer inside the issuance escrow
                if (transfer.isEther) {
                    issuanceEscrow.transfer(transfer.fromAddress, transfer.toAddress, transfer.amount);
                } else {
                    issuanceEscrow.transferToken(transfer.fromAddress, transfer.toAddress, transfer.tokenAddress, transfer.amount);
                }
            }
        }
    }

    /****************************************************************
     * Hook methods for Instrument type-specific implementations.
     ***************************************************************/

    /**
     * @dev Instrument type-specific issuance creation processing.
     * @param issuanceId ID of the issuance.
     * @param makerAddress Address of the maker which creates the new issuance.
     * @param makerParameters Custom issuance parameters.
     */
    function _processCreateIssuance(uint256 issuanceId, address makerAddress, bytes memory makerParameters)
        internal returns (InstrumentBase.IssuanceStates);

    /**
     * @dev Instrument type-specific issuance engage processing.
     * @param issuanceId ID of the issuance.
     * @param takerAddress Address of the taker which engages the issuance.
     * @param takerParameters Custom engagement parameters.
     * @param state The current issuance state
     * @param escrow The Issuance Escrow for this issuance.
     */
    function _processEngageIssuance(uint256 issuanceId, address takerAddress, bytes memory takerParameters,
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow) internal returns (InstrumentBase.IssuanceStates, bytes memory);

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
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow) internal returns (InstrumentBase.IssuanceStates, bytes memory);

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
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow) internal returns (InstrumentBase.IssuanceStates, bytes memory);

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
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow) internal returns (InstrumentBase.IssuanceStates, bytes memory);

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
        InstrumentBase.IssuanceStates state, EscrowBaseInterface escrow) internal returns (InstrumentBase.IssuanceStates, bytes memory);
}