pragma solidity ^0.5.0;

import "../InstrumentConfig.sol";
import "../lib/access/Ownable.sol";
import "../lib/proxy/AdminUpgradeabilityProxy.sol";
import "./InstrumentManagerInterface.sol";
import "./InstrumentManagerFactoryInterface.sol";

contract InstrumentManagerFactory is InstrumentManagerFactoryInterface, Ownable {

    // Mapping: version => Instrument manager implementation address.
    mapping(string => address) private _instrumentManagerImplementations;

    /**
     * @dev Updates the implementation for instrument manager.
     */
    function setInstrumentManagerImplementation(string memory version, address instrumentManagerImplementation) public onlyOwner {
        _instrumentManagerImplementations[version] = instrumentManagerImplementation;
    }

    /**
     * @dev Create a new instrument manager instance
     * @param version The instrument manager version
     * @param fspAddress The address of fsp who creates the instrument.
     * @param instrumentAddress The address of the instrument
     * @param instrumentConfigAddress The address of the instrument config.
     * @param instrumentParameters The custom parameters to this instrument manager.
     */
    function createInstrumentManagerInstance(string memory version, address fspAddress, address instrumentAddress,
        address instrumentConfigAddress, bytes memory instrumentParameters) public returns (InstrumentManagerInterface) {
        require(_instrumentManagerImplementations[version] != address(0x0), "InstrumentManagerFactory: Version not implemented.");
        require(fspAddress != address(0x0), "InstrumentManagerFactory: FSP address not set.");
        require(instrumentAddress != address(0x0), "InstrumentManagerFactory: Instrument address not set.");
        require(instrumentConfigAddress != address(0x0), "InstrumentManagerFactory: Instrument config address not set.");

        // Create Instrument Manager Proxy
        InstrumentConfig instrumentConfig = InstrumentConfig(instrumentConfigAddress);
        AdminUpgradeabilityProxy instrumentManagerProxy = new AdminUpgradeabilityProxy(_instrumentManagerImplementations[version],
            instrumentConfig.proxyAdminAddress(), new bytes(0));

        // Initialize Instrument Manager
        InstrumentManagerInterface proxiedInstrumentManager = InstrumentManagerInterface(address(instrumentManagerProxy));
        proxiedInstrumentManager.initialize(fspAddress, instrumentAddress, instrumentConfigAddress, instrumentParameters);

        return proxiedInstrumentManager;
    }

}