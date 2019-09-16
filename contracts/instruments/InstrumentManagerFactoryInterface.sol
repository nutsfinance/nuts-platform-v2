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
     * @param version The instrument manager version.
     * @param instrumentParameters Custom parameters about this instrument.
     * @return The address of the created Instrument Manager.
     */
    function createInstrumentManager(address fspAddress, address instrumentAddress, address instrumentConfigAddress,
        string calldata version, bytes calldata instrumentParameters)
        external returns (address instrumentManagerAddress);
}