pragma solidity ^0.5.0;

import "../InstrumentConfig.sol";
import "./InstrumentManagerInterface.sol";
import "./v1/InstrumentV1Manager.sol";
import "./v2/InstrumentV2Manager.sol";
import "./v3/InstrumentV3Manager.sol";
import "../lib/util/StringUtil.sol";
import "../lib/proxy/AdminUpgradeabilityProxy.sol";

contract InstrumentManagerFactory {
    using StringUtil for string;

    /**
     * @dev Create a new instrument manager instance
     * @param fspAddress The address of the FSP who deploy the instrument.
     * @param instrumentAddress The deployed address of the instrument.
     * @param instrumentConfigAddress The address of InstrumentConfig contract.
     * @param version The instrument manager version.
     * @param instrumentParameters Custom parameters about this instrument.
     * @return The address of the created Instrument Manager.
     */
    function createInstrumentManager(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        string memory version, bytes memory instrumentParameters)
        public returns (address instrumentManagerAddress) {

        // Create Instrument Manager contract.
        InstrumentManagerInterface instrumentManager;
        if (version.equals("v1")) {
            instrumentManager = new InstrumentV1Manager();
        } else if (version.equals("v2")) {
            instrumentManager = new InstrumentV2Manager();
        } else if (version.equals("v3")) {
            instrumentManager = new InstrumentV3Manager();
        } else {
            revert("Unknown instrument version.");
        }

        // Create AdminUpgradeabilityProxy for Instrument Manager
        AdminUpgradeabilityProxy instrumentManagerProxy = new AdminUpgradeabilityProxy(address(instrumentManager),
            InstrumentConfig(instrumentConfigAddress).proxyAdminAddress(), new bytes(0));

        // Initialize Instrument Manager
        InstrumentManagerInterface(address(instrumentManagerProxy)).initialize(fspAddress, instrumentAddress, instrumentConfigAddress,
            instrumentParameters);

        instrumentManagerAddress = address(instrumentManagerProxy);
    }
}