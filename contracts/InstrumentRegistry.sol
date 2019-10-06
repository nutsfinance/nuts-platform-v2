pragma solidity ^0.5.0;

import "./escrow/DepositEscrowInterface.sol";
import "./escrow/EscrowFactoryInterface.sol";
import "./instruments/InstrumentManagerInterface.sol";
import "./instruments/InstrumentManagerFactoryInterface.sol";
import "./lib/token/IERC20.sol";
import "./lib/token/SafeERC20.sol";
import "./lib/access/Ownable.sol";
import "./InstrumentConfig.sol";

/**
 * @title Instrument Registry.
 */
contract InstrumentRegistry is Ownable, InstrumentConfig {

    using SafeERC20 for IERC20;

    // Mapping: Instrument version => Instrument Manager Factory
    mapping(bytes32 => InstrumentManagerFactoryInterface) private _instrumentManagerFactories;
    // Mapping: Instrument Address => Instrument Manager Address
    mapping(address => address) _instrumentManagers;

    /**
     * @dev Initialization method for Instrument Registry.
     * @param owner Owner of Instrument Registry.
     * @param instrumentDeposit The NUTS token deposited for new Instrument,
     * @param issuanceDeposit The NUTS token deposited for new Issuance.
     * @param depositTokenAddress Address of NUTS token.
     * @param proxyAdminAddress Address of proxy admin.
     * @param timerOracleAddress Address of Timer Oracle
     * @param priceOracleAddress Address of Price Oracle
     */
    function initialize(address owner, uint256 instrumentDeposit, uint256 issuanceDeposit, address depositTokenAddress,
        address proxyAdminAddress, address timerOracleAddress, address priceOracleAddress, address escrowFactoryAddress) public {
        require(address(depositTokenAddress) == address(0x0), "InstrumentRegistry: Already initialized.");
        require(owner != address(0x0), "InstrumentRegistry: Owner must be provided.");
        require(depositTokenAddress != address(0x0), "InstrumentRegistry: Deposit token address must be provided.");
        require(proxyAdminAddress != address(0x0), "InstrumentRegistry: Proxy admin address must be provided.");
        require(timerOracleAddress != address(0x0), "InstrumentRegistry: Timer Oracle address must be provided.");
        require(priceOracleAddress != address(0x0), "InstrumentRegistry: Price Oracle address must be provided.");
        require(escrowFactoryAddress != address(0x0), "InstrumentRegistry: Escrow Factory address must be provided.");

        // Set owner
        _transferOwnership(owner);

        // Create new Deposit Escrow
        DepositEscrowInterface depositEscrow = EscrowFactoryInterface(escrowFactoryAddress)
            .createDepositEscrow(proxyAdminAddress, address(this));

        InstrumentConfig.initialize(instrumentDeposit, issuanceDeposit, address(depositEscrow), depositTokenAddress,
            proxyAdminAddress, timerOracleAddress, priceOracleAddress, escrowFactoryAddress);
    }

    /**
     * @dev Update Instrument Manager Factory
     */
    function setInstrumentManagerFactory(bytes32 version, InstrumentManagerFactoryInterface instrumentManagerFactory) public onlyOwner {
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
     * @dev Update proxy admin address.
     */
    function setProxyAdminAddress(address newProxyAdminAddress) public onlyOwner {
        proxyAdminAddress = newProxyAdminAddress;
    }

    /**
     * @dev Update Timer Oracle address.
     */
    function setTimerOracleAddress(address newTimerOracleAddress) public onlyOwner {
        timerOracleAddress = newTimerOracleAddress;
    }

    function setEscrowFactoryAddress(address newEscrowFactoryAddress) public onlyOwner {
        escrowFactoryAddress = newEscrowFactoryAddress;
    }

    /**
     * @dev MOST IMPORTANT method: Activate new financial instrument.
     * @param instrumentAddress Address of Instrument to activate.
     * @param version Version of Instrument.
     * @param instrumentParameters Custom parameters for this instrument.
     */
    function activateInstrument(address instrumentAddress, bytes32 version, bytes memory instrumentParameters)
        public returns (InstrumentManagerInterface instrumentManager) {
        require(_instrumentManagers[instrumentAddress] == address(0x0), "InstrumentRegistry: Instrument already activated.");
        require(instrumentAddress != address(0x0), "InstrumentRegistry: Instrument address must be provided.");
        require(address(_instrumentManagerFactories[version]) != address(0x0), "InstrumentRegistry: Version not supported.");

        // Create Instrument Manager
        instrumentManager = _instrumentManagerFactories[version].createInstrumentManager(msg.sender, instrumentAddress,
            address(this), instrumentParameters);
        
        // Transfer NUTS token to deposit from FSP
        IERC20(depositTokenAddress).safeTransferFrom(msg.sender, address(this), instrumentDeposit);
        // Deposit the NUTS token to Deposit Escrow, under the account of the newly created Instrument Manager.
        IERC20(depositTokenAddress).safeApprove(depositEscrowAddress, instrumentDeposit);
        DepositEscrowInterface(depositEscrowAddress).depositTokenByAdmin(address(instrumentManager), depositTokenAddress, instrumentDeposit);
    }

    /**
     * @dev Retrieve Instrument Manager address by Instrument address.
     */
    function lookupInstrumentManager(address instrumentAddress) public view
        returns (address instrumentManagerAddress) {
        return _instrumentManagers[instrumentAddress];
    }
}
