pragma solidity ^0.5.0;

import "./InstrumentManagerInterface.sol";

/**
 * @title The interface of instrument manager factory.
 * Instrument registry uses this interface to create new instrument manager.
 */
interface InstrumentManagerFactoryInterface {

    /**
     * @dev Create a new instrument manager instance
     * @param fspAddress The address of the FSP who deploy the instrument.
     * @param instrumentAddress The deployed address of the instrument.
     * @param instrumentConfigAddress The address of InstrumentConfig contract.
     * @param instrumentParameters Custom parameters about this instrument.
     * @return The created Instrument Manager.
     */
    function createInstrumentManager(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        bytes calldata instrumentParameters) external returns (InstrumentManagerInterface);
}