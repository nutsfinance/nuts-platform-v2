pragma solidity ^0.5.0;

import "../InstrumentManagerFactoryInterface.sol";
import "../InstrumentManagerInterface.sol";
import "./InstrumentV3Manager.sol";

contract InstrumentV3ManagerFactory is InstrumentManagerFactoryInterface {
    /**
     * @dev Create a new instrument manager instance
     * @param fspAddress The address of fsp who creates the instrument.
     * @param instrumentAddress The address of the instrument
     * @param instrumentConfigAddress The address of the instrument config.
     * @param instrumentParameters The custom parameters to this instrument manager.
     */
    function createInstrumentManagerInstance(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        bytes memory instrumentParameters) public returns (InstrumentManagerInterface) {
        InstrumentV3Manager manager = new InstrumentV3Manager(fspAddress, instrumentAddress, instrumentConfigAddress, instrumentParameters);

        return manager;
    }
}
