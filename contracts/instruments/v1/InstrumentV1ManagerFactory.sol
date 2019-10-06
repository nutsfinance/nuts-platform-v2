pragma solidity ^0.5.0;

import "../InstrumentManagerInterface.sol";
import "../InstrumentManagerFactoryBase.sol";
import "./InstrumentV1Manager.sol";

contract InstrumentV1ManagerFactory is InstrumentManagerFactoryBase {
    /**
     * @dev Create instance of Instrument Manager.
     */
    function _createInstrumentManagerInstance() internal returns (InstrumentManagerInterface) {
        return new InstrumentV1Manager();
    }
}