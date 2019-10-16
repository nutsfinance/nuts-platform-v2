pragma solidity ^0.5.0;

import "../InstrumentManagerFactoryInterface.sol";
import "../InstrumentManagerInterface.sol";
import "./InstrumentV2Manager.sol";

contract InstrumentV2ManagerFactory is InstrumentManagerFactoryInterface {

    address private _storageFactoryAddress;

    constructor(address storageFactoryAddress) public {
        _storageFactoryAddress = storageFactoryAddress;
    }

    /**
     * @dev Create a new instrument manager instance
     * @param fspAddress The address of fsp who creates the instrument.
     * @param instrumentAddress The address of the instrument
     * @param instrumentConfigAddress The address of the instrument config.
     * @param instrumentParameters The custom parameters to this instrument manager.
     */
    function createInstrumentManagerInstance(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        bytes memory instrumentParameters) public returns (InstrumentManagerInterface) {
        InstrumentV2Manager manager = new InstrumentV2Manager(fspAddress, instrumentAddress, instrumentConfigAddress,
            instrumentParameters, _storageFactoryAddress);

        return manager;
    }
}