pragma solidity ^0.5.0;

import "../InstrumentManagerFactoryInterface.sol";
import "../InstrumentManagerInterface.sol";
import "./InstrumentV1Manager.sol";

contract InstrumentV1ManagerFactory is InstrumentManagerFactoryInterface {
    /**
     * @dev Create a new instrument manager instance
     * @param fspAddress The address of fsp who creates the instrument.
     * @param instrumentAddress The address of the instrument
     * @param instrumentConfigAddress The address of the instrument config.
     * @param instrumentParameters The custom parameters to this instrument manager.
     */
    function createInstrumentManagerInstance(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        bytes memory instrumentParameters) public returns (InstrumentManagerInterface) {
        InstrumentV1Manager manager = new InstrumentV1Manager(fspAddress, instrumentAddress, instrumentConfigAddress, instrumentParameters);

        return manager;
    }
}