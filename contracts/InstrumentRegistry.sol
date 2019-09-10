pragma solidity ^0.5.0;

import "./instruments/InstrumentManagerInterface.sol";
import "./instruments/InstrumentManagerFactoryInterface.sol";
import "./lib/protobuf/InstrumentRegistryData.sol";
import "./lib/token/IERC20.sol";

contract InstrumentRegistry {

    /**
     * Defines common properties shared by all instruments.
     */
    struct InstrumentProperty {

    }

    /**
     * Defines common properties shared by all issuances.
     */
    struct IssuanceProperty {

    }

    /**
     * The last id used in this id sequence.
     */
    uint256 private _lastId;
    /**
     * The deposit amount required to create a new instrument.
     */
    uint256 private _instrumentDeposit;
    /**
     * The deposit amount required to create a new issuance.
     */
    uint256 private _issuanceDeposit;
    /**
     * The address to hold the deposits.
     */
    address private _depositEscrow;
    /**
     * Factory to create new instrument managers.
     */
    InstrumentManagerFactoryInterface private _instrumentManagerFactory;
    /**
     * The deposit token.
     */
    IERC20 private _depositToken;
    mapping(uint256 => InstrumentProperty) private _instrumentProperties;
    mapping(uint256 => IssuanceProperty) private _issuanceProperties;

    /**
     * @dev Initialize the instrument registry.
     * This is not done via constructor as the 
     */
    function initialize(uint256 lastId, uint256 instrumentDeposit, uint256 issuanceDeposit, address depositEscrow,
        address instrumentManagerFactoryAddress, address depositTokenAddress) public {
        require(address(_depositEscrow) == address(0x0), "InstrumentRegistry: Already initialized.");
        require(instrumentManagerFactoryAddress != address(0x0), "InstrumentRegistry: Instrument manager factory must be set.");
        require(depositTokenAddress != address(0x0), "InstrumentRegistry: Deposit token must be set. ");
        _lastId = lastId;
        _instrumentDeposit = instrumentDeposit;
        _issuanceDeposit = issuanceDeposit;
        _instrumentManagerFactory = InstrumentManagerFactoryInterface(instrumentManagerFactoryAddress);
        _depositToken = IERC20(depositTokenAddress);
    }

    function createInstrument(address instrumentAddress, string memory version, bytes memory instrumentParameters) public returns (uint256) {
        // Finish deposit for instrument creation
        require(_depositToken.transferFrom(msg.sender, _depositEscrow, _instrumentDeposit),
            "Instrument Registry: Insufficent balance for deposit.");
        uint256 instrumentId = _lastId;
        _lastId = _lastId + 1;
        InstrumentManagerInterface instrumentManager = _instrumentManagerFactory.createInstrumentManager(instrumentAddress,
            msg.sender, version, instrumentParameters);
        InstrumentProperties.Data memory properties = InstrumentProperties.Data({
            instrumentManagerAddress: address(instrumentManager),
            fspAddress: msg.sender,
            activeness: uint8(InstrumentManagerFactory.InstrumentActiveness.Active),
            creation: now,
            tokenDeposited: _instrumentDeposit
        });
        _instrumentProperties[instrumentId] = InstrumentProperties.encode(properties);

        return instrumentId;
    }

    function deactivateInstrument(uint256 instrumentId) public {
        require(_instrumentProperties[instrumentId].length > 0, "InstrumentRegistry: Instrument does not exist.");
        InstrumentProperties.Data memory properties = InstrumentProperties.decode(_instrumentProperties[instrumentId]);
        properties.state = uint8(InstrumentManagerFactory.InstrumentActiveness.Inactive);
    }

    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceId The id of the issuance
     * @param sellerAddress The address of the seller who creates this issuance
     * @param sellerParameters The custom parameters to the newly created issuance
     * @return activeness The activeness of the issuance.
     */
    function createIssuance(uint256 issuanceId, address sellerAddress, bytes calldata sellerParameters)
        external returns (address instrumentManagerAddress, address instrumentEscrowAddress);

}