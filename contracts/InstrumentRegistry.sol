pragma solidity ^0.5.0;

import "./escrow/DepositEscrowInterface.sol";
import "./escrow/EscrowFactoryInterface.sol";
import "./instrument/InstrumentManagerInterface.sol";
import "./instrument/InstrumentManagerFactoryInterface.sol";
import "./lib/token/IERC20.sol";
import "./lib/token/SafeERC20.sol";
import "./lib/access/Ownable.sol";
import "./InstrumentConfig.sol";

/**
 * @title Instrument Registry.
 */
contract InstrumentRegistry is Ownable, InstrumentConfig {

    event InstrumentActivated(uint256 indexed instrumentId, address indexed fspAddress, address indexed instrumentAddress,
        address instrumentManagerAddress, address instrumentEscrowAddress);

    using SafeERC20 for IERC20;

    uint256 private _lastInstrumentId;
    // Mapping: Instrument ID => Instrument Manager Address
    mapping(uint256 => address) private _instrumentManagers;
    // Mapping: Version => Instrument Manager Factory
    InstrumentManagerFactoryInterface private _instrumentManagerFactory;

    /**
     * @dev Initialization method for Instrument Registry.
     * @param newInstrumentDeposit The NUTS token deposited for new Instrument,
     * @param newIssuanceDeposit The NUTS token deposited for new Issuance.
     * @param newDepositTokenAddress Address of NUTS token.
     * @param newPriceOracleAddress Address of Price Oracle
     * @param newEscrowFactoryAddress Address of Escrow Factory.
     */
    constructor(address instrumentManagerFactoryAddress, uint256 newInstrumentDeposit, uint256 newIssuanceDeposit,
        address newDepositTokenAddress, address newPriceOracleAddress, address newEscrowFactoryAddress) public {
        require(address(_instrumentManagerFactory) == address(0x0), "Registry already initialized");
        require(newDepositTokenAddress != address(0x0), "Deposit token address not set");
        require(newPriceOracleAddress != address(0x0), "Price Oracle address not set");
        require(newEscrowFactoryAddress != address(0x0), "Escrow Factory address not set");

        _instrumentManagerFactory = InstrumentManagerFactoryInterface(instrumentManagerFactoryAddress);
        instrumentDeposit = newInstrumentDeposit;
        issuanceDeposit = newIssuanceDeposit;
        depositTokenAddress = newDepositTokenAddress;
        priceOracleAddress = newPriceOracleAddress;
        escrowFactoryAddress = newEscrowFactoryAddress;

        // Create new Deposit Escrow
        EscrowFactoryInterface escrowFactory = EscrowFactoryInterface(newEscrowFactoryAddress);
        depositEscrowAddress = address(escrowFactory.createDepositEscrow());
    }

    /**
     * @dev Update Instrument Manager Factory
     */
    function setInstrumentManagerFactory(InstrumentManagerFactoryInterface instrumentManagerFactory) public onlyOwner {
        _instrumentManagerFactory = instrumentManagerFactory;
    }

    /**
     * @dev Update instrument deposit amount.
     */
    function setInstrumentDeposit(uint256 newInstrumentDeposit) public onlyOwner {
        instrumentDeposit = newInstrumentDeposit;
    }

    /**
     * @dev Update issuance deposit amount.
     */
    function setIssuanceDeposit(uint256 newIssuanceDeposit) public onlyOwner {
        issuanceDeposit = newIssuanceDeposit;
    }

    /**
     * @dev Update Escrow Factory address.
     */
    function setEscrowFactoryAddress(address newEscrowFactoryAddress) public onlyOwner {
        escrowFactoryAddress = newEscrowFactoryAddress;
    }

    /**
     * @dev MOST IMPORTANT method: Activate new financial instrument.
     * @param instrumentAddress Address of Instrument to activate.
     * @param instrumentParameters Custom parameters for this instrument.
     */
    function activateInstrument(address instrumentAddress, bytes memory instrumentParameters)
        public returns (InstrumentManagerInterface) {
        require(instrumentAddress != address(0x0), "Instrument address not set");

        _lastInstrumentId++;
        // Create Instrument Manager
        InstrumentManagerInterface instrumentManager = _instrumentManagerFactory.createInstrumentManagerInstance(
            _lastInstrumentId, msg.sender, instrumentAddress, address(this), instrumentParameters);

        _instrumentManagers[_lastInstrumentId] = address(instrumentManager);

        emit InstrumentActivated(_lastInstrumentId, msg.sender, instrumentAddress, address(instrumentManager),
            instrumentManager.getInstrumentEscrowAddress());

        if (instrumentDeposit > 0) {
            // Transfer NUTS token to deposit from FSP
            IERC20(depositTokenAddress).safeTransferFrom(msg.sender, address(this), instrumentDeposit);
            // Deposit the NUTS token to Deposit Escrow, under the account of the newly created Instrument Manager.
            IERC20(depositTokenAddress).safeApprove(depositEscrowAddress, instrumentDeposit);
            DepositEscrowInterface(depositEscrowAddress).depositTokenByAdmin(address(instrumentManager),
                depositTokenAddress, instrumentDeposit);
        }

        return instrumentManager;
    }

    /**
     * @dev Retrieve Instrument Manager address by Instrument ID.
     */
    function lookupInstrumentManager(uint256 instrumentId) public view returns (address instrumentManagerAddress) {
        return _instrumentManagers[instrumentId];
    }
}
