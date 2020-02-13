pragma solidity 0.5.16;

import "./InstrumentManagerFactoryInterface.sol";
import "./InstrumentManagerInterface.sol";
import "./InstrumentManager.sol";

contract InstrumentManagerFactory is InstrumentManagerFactoryInterface {

    /**
     * @dev Create a new instrument manager instance
     * @param instrumentId The id of the instrument.
     * @param fspAddress The address of fsp who creates the instrument.
     * @param instrumentAddress The address of the instrument
     * @param instrumentConfigAddress The address of the instrument config.
     * @param instrumentParameters The custom parameters to this instrument manager.
     */
    function createInstrumentManagerInstance(uint256 instrumentId, address fspAddress, address instrumentAddress,
        address instrumentConfigAddress, bytes memory instrumentParameters) public returns (InstrumentManagerInterface) {

        InstrumentManager manager = new InstrumentManager(instrumentId, fspAddress, instrumentAddress,
            instrumentConfigAddress, instrumentParameters);
        return manager;
    }
}
