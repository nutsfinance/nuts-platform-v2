pragma solidity ^0.5.0;

import "./InstrumentManagerInterface.sol";
import "./v1/InstrumentV1Manager.sol";
import "./v2/InstrumentV2Manager.sol";
import "./v3/InstrumentV3Manager.sol";
import "../escrow/InstrumentEscrow.sol";
import "../lib/util/StringUtil.sol";

contract InstrumentManagerFactory {
    /**
     * @dev Create a new instrument manager instance
     * @param instrumentAddress The deployed address of the instrument.
     * @param fspAddress The address of the FSP who deploy the instrument.
     * @param version The instrument manager version.
     * @param instrumentParameters Custom parameters about this instrument.
     */
    function createInstrumentManager(address instrumentAddress, address fspAddress, string memory version, bytes memory instrumentParameters)
        public returns (address instrumentManagerAddress, address instrumentEscrowAddress) {
        // if (StringUtil.equals(version, "v1")) {
        //     // Create new InstrumentEscrow instance
        //     InstrumentEscrow escrow = new InstrumentEscrow();
        //     // Create new Proxy for the InstrumentEscrow instance
        //     OwnerOnlyUpgradeabilityProxy escrowProxy = new OwnerOnlyUpgradeabilityProxy();
        //     escrowProxy.upgradeTo(address(escrow));

        //     // Create new InstrumentV1Manager instance
        //     InstrumentV1Manager manager = new InstrumentV1Manager();
        //     // Create new Proxy for InstrumentV1Manager
        //     OwnerOnlyUpgradeabilityProxy managerProxy = new OwnerOnlyUpgradeabilityProxy();
        //     managerProxy.upgradeTo(address(manager));
        //     // Transfer escrow proxy ownership to instrument manager proxy
        //     escrowProxy.transferProxyOwnership(address(managerProxy));

        //     InstrumentEscrow proxiedEscrow = InstrumentEscrow(address(escrowProxy));
        //     InstrumentV1Manager proxiedManager = InstrumentV1Manager(address(managerProxy));
        //     // Initialize the instrument manager.
        //     // Please note that for escrow parameter, it's the proxy instead of the escrow instance!
        //     proxiedManager.initialize(InstrumentV1(instrumentAddress), proxiedEscrow, fspAddress, instrumentParameters);

        //     // Transfer manager proxy ownership after initialization
        //     managerProxy.transferProxyOwnership(msg.sender);
            
        //     return manager;
        // } else if (StringUtil.equals(version, "v2")) {

        // } else if (StringUtil.equals(version, "v3")) {

        // } else {
        //     revert("Unknown instrument version.");
        // }
    }
}