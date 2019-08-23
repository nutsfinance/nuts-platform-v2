pragma solidity ^0.5.0;

import "./InstrumentManagerInterface.sol";

/**
 * @title The interface of instrument manager factory.
 * Instrument registry uses this interface to create new instrument manager.
 */
interface InstrumentManagerFactoryInterface {

    /**
     * @dev Create a new instrument manager instance
     * @param instrumentAddress The deployed address of the instrument.
     * @param fspAddress The address of the FSP who deploy the instrument.
     * @param version The instrument manager version.
     * @param instrumentParameters Custom parameters about this instrument.
     */
    function createInstrumentManager(address instrumentAddress, address fspAddress, string calldata version, bytes calldata instrumentParameters)
        external returns (InstrumentManagerInterface);
}