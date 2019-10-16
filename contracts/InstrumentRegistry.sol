pragma solidity ^0.5.0;

import "./escrow/DepositEscrowInterface.sol";
import "./escrow/EscrowFactoryInterface.sol";
import "./storage/StorageFactoryInterface.sol";
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

    using SafeERC20 for IERC20;

    // Mapping: Instrument Address => Instrument Manager Address
    mapping(address => address) private _instrumentManagers;
    // Mapping: Version => Instrument Manager Factory
    mapping(string => InstrumentManagerFactoryInterface) private _instrumentManagerFactories;

    /**
     * @dev Initialization method for Instrument Registry.
     * @param newInstrumentDeposit The NUTS token deposited for new Instrument,
     * @param newIssuanceDeposit The NUTS token deposited for new Issuance.
     * @param newDepositTokenAddress Address of NUTS token.
     * @param newPriceOracleAddress Address of Price Oracle
     * @param newEscrowFactoryAddress Address of Escrow Factory.
     */
    constructor(uint256 newInstrumentDeposit, uint256 newIssuanceDeposit, address newDepositTokenAddress,
        address newPriceOracleAddress, address newEscrowFactoryAddress) public {
        require(address(depositTokenAddress) == address(0x0), "Registry already initialized");
        require(newDepositTokenAddress != address(0x0), "Deposit token address not set");
        require(newPriceOracleAddress != address(0x0), "Price Oracle address not set");
        require(newEscrowFactoryAddress != address(0x0), "Escrow Factory address not set");

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
    function setInstrumentManagerFactory(string memory version, InstrumentManagerFactoryInterface instrumentManagerFactory) public onlyOwner {
        _instrumentManagerFactories[version] = instrumentManagerFactory;
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
     * @param version Version of Instrument.
     * @param instrumentParameters Custom parameters for this instrument.
     */
    function activateInstrument(address instrumentAddress, string memory version, bytes memory instrumentParameters)
        public returns (InstrumentManagerInterface) {
        require(_instrumentManagers[instrumentAddress] == address(0x0), "Instrument already activated");
        require(instrumentAddress != address(0x0), "Instrument address not set");

        // Create Instrument Manager
        InstrumentManagerInterface instrumentManager = _instrumentManagerFactories[version].createInstrumentManagerInstance(
            msg.sender, instrumentAddress, address(this), instrumentParameters);

        _instrumentManagers[instrumentAddress] = address(instrumentManager);

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
     * @dev Retrieve Instrument Manager address by Instrument address.
     */
    function lookupInstrumentManager(address instrumentAddress) public view
        returns (address instrumentManagerAddress) {
        return _instrumentManagers[instrumentAddress];
    }
}
