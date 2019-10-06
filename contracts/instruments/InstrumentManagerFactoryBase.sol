pragma solidity ^0.5.0;

import "../InstrumentConfig.sol";
import "./InstrumentManagerInterface.sol";
import "./InstrumentManagerFactoryInterface.sol";
import "./v1/InstrumentV1Manager.sol";
import "./v2/InstrumentV2Manager.sol";
import "./v3/InstrumentV3Manager.sol";
import "../lib/proxy/AdminUpgradeabilityProxy.sol";

contract InstrumentManagerFactoryBase is InstrumentManagerFactoryInterface {

    /**
     * @dev Create a new instrument manager instance
     * @param fspAddress The address of the FSP who deploy the instrument.
     * @param instrumentAddress The deployed address of the instrument.
     * @param instrumentConfigAddress The address of InstrumentConfig contract.
     * @param instrumentParameters Custom parameters about this instrument.
     * @return The created Instrument Manager.
     */
    function createInstrumentManager(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        bytes memory instrumentParameters) public returns (InstrumentManagerInterface) {

        InstrumentManagerInterface instrumentManager = _createInstrumentManagerInstance();

        // Create AdminUpgradeabilityProxy for Instrument Manager
        AdminUpgradeabilityProxy instrumentManagerProxy = new AdminUpgradeabilityProxy(address(instrumentManager),
            InstrumentConfig(instrumentConfigAddress).proxyAdminAddress(), new bytes(0));

        // Initialize Instrument Manager
        InstrumentManagerInterface proxiedInstrumentManager = InstrumentManagerInterface(address(instrumentManagerProxy));
        proxiedInstrumentManager.initialize(fspAddress, instrumentAddress, instrumentConfigAddress,
            instrumentParameters);

        return proxiedInstrumentManager;
    }

    /**
     * @dev Create instance of Instrument Manager.
     */
    function _createInstrumentManagerInstance() internal returns (InstrumentManagerInterface);
}