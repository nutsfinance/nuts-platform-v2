pragma solidity ^0.5.0;

import "./InstrumentManagerInterface.sol";
import "../escrow/InstrumentEscrow.sol";
import "../escrow/IssuanceEscrow.sol";
import "../lib/token/IERC20.sol";
import "../lib/protobuf/InstrumentData.sol";
import "../lib/protobuf/TokenTransfer.sol";

/**
 * Base instrument manager for instrument v1, v2 and v3.
 */
contract InstrumentManagerBase is InstrumentManagerInterface {
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
    uint256 internal _lastIssuanceId;
    InstrumentEscrow internal _instrumentEscrow;
    mapping(uint256 => address) internal _issuanceEscrows;

    constructor(address fspAddress, address instrumentEscrowAddress, bytes memory instrumentParameters) public {
        require(fspAddress != address(0x0), "InstrumentManagerBase: FSP address must be provided.");
        require(instrumentParameters.length > 0, "InstrumentManagerBase: Instrument parameters must be provided.");

        InstrumentParameters.Data memory parameters = InstrumentParameters.decode(instrumentParameters);
        _active = true;
        _expiration = parameters.expiration;
        _startTimestamp = now;
        _makerWhitelistEnabled = parameters.supportMakerWhitelist;
        _takerWhitelistEnabled = parameters.supportTakerWhitelist;
        _fspAddress = fspAddress;
        _lastIssuanceId = 1;
        _instrumentEscrow = InstrumentEscrow(instrumentEscrowAddress);

        // TODO Deposit NUTS token.
    }

    /**
     * @dev Deactivates the instrument.
     */
    function deactivate() public {
        require(_active, "InstrumentManagerBase: The instrument is already deactivated.");
        require(msg.sender == _fspAddress, "InstrumentManagerBase: Only FSP can deactivate the instrument.");

        // TODO Return the deposited NUTS token
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

    function _createIssuanceEscrow(uint256 issuanceId) internal returns (address) {

    }

    /**
     * @dev Process the transfers triggered by Instrumetns.
     */
    function _processTransfers(uint256 issuanceId, bytes memory transfersData) internal {
        Transfers.Data memory transfers = Transfers.decode(transfersData);
        IssuanceEscrow issuanceEscrow = IssuanceEscrow(_issuanceEscrows[issuanceId]);
        for (uint256 i = 0; i < transfers.actions.length; i++) {
            Transfer.Data memory transfer = transfers.actions[i];
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
                    IERC20(transfer.tokenAddress).approve(address(_instrumentEscrow), transfer.amount);
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
}