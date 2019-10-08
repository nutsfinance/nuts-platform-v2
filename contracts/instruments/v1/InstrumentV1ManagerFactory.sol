pragma solidity ^0.5.0;

import "../InstrumentManagerInterface.sol";
import "../InstrumentManagerFactoryInterface.sol";
import "./InstrumentV1Manager.sol";

contract InstrumentV1ManagerFactory is InstrumentManagerFactoryInterface {
    /**
     * @dev Create instance of Instrument Manager.
     */
    function createInstrumentManagerInstance() public returns (InstrumentManagerInterface) {
        return new InstrumentV1Manager();
    }
}