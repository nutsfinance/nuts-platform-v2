pragma solidity ^0.5.0;

import "./InstrumentManagerInterface.sol";

/**
 * @title The interface of instrument manager factory.
 * Instrument registry uses this interface to create new instrument manager.
 */
interface InstrumentManagerFactoryInterface {

    /**
     * @dev Create a new instrument manager instance
     * @param fspAddress The address of fsp who creates the instrument.
     * @param instrumentAddress The address of the instrument
     * @param instrumentConfigAddress The address of the instrument config.
     * @param instrumentParameters The custom parameters to this instrument manager.
     */
    function createInstrumentManagerInstance(address fspAddress, address instrumentAddress,
        address instrumentConfigAddress, bytes calldata instrumentParameters) external returns (InstrumentManagerInterface);
}
